#!/usr/bin/env python3
"""Read-only acceptance checks for the published static site. Requires curl."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urljoin

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("host")
parser.add_argument("--evidence", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent
base = f"https://{args.host}"
routes = {
    "/": (200, "index.html"),
    "/privacy/": (200, "privacy/index.html"),
    "/support/": (200, "support/index.html"),
    "/assets/site.css": (200, "assets/site.css"),
    "/assets/app-icon.svg": (200, "assets/app-icon.svg"),
    "/robots.txt": (200, "robots.txt"),
    "/acceptance/missing/page": (404, "404.html"),
}
aliases = {
    "/privacy": "/privacy/", "/privacy-policy": "/privacy/",
    "/privacy-policy/": "/privacy/", "/privacy.html": "/privacy/",
    "/support": "/support/", "/support.html": "/support/",
}
expected_headers = {
    "content-security-policy": "default-src 'none'; style-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'",
    "strict-transport-security": "max-age=31536000",
    "x-content-type-options": "nosniff",
    "x-frame-options": "DENY",
    "referrer-policy": "no-referrer",
    "permissions-policy": "camera=(), microphone=(), geolocation=()",
}


def fetch(item):
    path, (status, filename) = item
    url = path if path.startswith("http:") else base + path
    with tempfile.TemporaryDirectory() as tmp:
        headers_file, body_file = Path(tmp) / "headers", Path(tmp) / "body"
        proc = subprocess.run([
            "curl", "--silent", "--show-error", "--max-time", "25",
            "--dump-header", str(headers_file), "--output", str(body_file),
            "--write-out", "%{http_code} %{ssl_verify_result}", url,
        ], capture_output=True, text=True)
        body = body_file.read_bytes() if body_file.exists() else b""
        raw_headers = headers_file.read_text() if headers_file.exists() else ""
    headers = {}
    # Ignore intermediary CONNECT headers if a proxy supplied them.
    for line in raw_headers.splitlines():
        if line.startswith("HTTP/"):
            headers = {}
        elif ":" in line:
            name, value = line.split(":", 1)
            headers[name.lower()] = value.strip()
    parts = proc.stdout.split()
    actual = int(parts[0]) if parts else 0
    checks = {"request_completed": proc.returncode == 0, "status": actual == status}
    if url.startswith("https:"):
        checks["tls_verified"] = len(parts) > 1 and parts[1] == "0"
    if filename:
        checks["exact_release_bytes"] = body == (root / "release" / filename).read_bytes()
        for name, value in expected_headers.items():
            checks[name] = headers.get(name) == value
        cache = {part.strip() for part in headers.get("cache-control", "").split(",")}
        # Pages forces no-store for missing routes; the custom-domain CDN may
        # raise an asset's max-age. Contact-page HTML must remain untransformed
        # and revalidated so email links work under the script-free CSP.
        if filename == "404.html":
            checks["cache_policy"] = "no-store" in cache
        elif filename.endswith(".html"):
            checks["cache_policy"] = {"max-age=0", "must-revalidate", "no-transform"} <= cache
        else:
            checks["cache_policy"] = {"must-revalidate", "no-transform"} <= cache
        checks["no_set_cookie"] = "set-cookie" not in headers
        checks["no_http_noindex"] = "x-robots-tag" not in headers
        if filename.endswith(".html"):
            checks["html_mime"] = headers.get("content-type", "").startswith("text/html")
            checks["no_injected_scripts"] = b"<script" not in body.lower()
        elif filename.endswith(".css"):
            checks["css_mime"] = headers.get("content-type", "").startswith("text/css")
        elif filename.endswith(".svg"):
            checks["svg_mime"] = headers.get("content-type", "").startswith("image/svg+xml")
    else:
        target = base + ("/privacy/" if path.startswith("http:") else aliases[path])
        checks["redirect_target"] = urljoin(url, headers.get("location", "")) == target
    return {
        "url": url, "status": actual, "checks": checks,
        "passed": all(checks.values()), "headers": headers,
        "bytes": len(body), "sha256": hashlib.sha256(body).hexdigest(),
        "error": proc.stderr or None,
    }


items = list(routes.items()) + [(p, (301, None)) for p in aliases]
items.append((f"http://{args.host}/privacy/", (301, None)))
with ThreadPoolExecutor(max_workers=4) as pool:
    results = list(pool.map(fetch, items))
report = {
    "checked_at": datetime.now(timezone.utc).isoformat(),
    "host": args.host, "passed": all(r["passed"] for r in results),
    "results": results,
    "scope": "Ordinary unauthenticated curl responses with TLS verification. Conditional security challenges/cookies are not ruled out.",
}
args.evidence.parent.mkdir(parents=True, exist_ok=True)
args.evidence.write_text(json.dumps(report, indent=2) + "\n")
for result in results:
    failed = [key for key, passed in result["checks"].items() if not passed]
    print(f"{'PASS' if result['passed'] else 'FAIL'} {result['status']} {result['url']} {failed}")
raise SystemExit(0 if report["passed"] else 1)
