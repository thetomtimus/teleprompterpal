#!/usr/bin/env python3
"""Check the static hosting bundle locally. Never contacts a host or deploys."""
import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit

ROOT = Path(__file__).resolve().parent
FILES = {
    "index.html", "privacy/index.html", "support/index.html", "404.html",
    "assets/site.css", "assets/app-icon.svg", "robots.txt", "_headers", "_redirects",
}


class Document(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links, self.h1 = set(), [], 0
        self.robots, self.canonical = None, None

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if "id" in values:
            assert values["id"] not in self.ids, "Duplicate element ID"
            self.ids.add(values["id"])
        self.h1 += tag == "h1"
        assert tag not in ("script", "form", "iframe"), f"Unexpected {tag}"
        if tag == "meta" and values.get("name") == "robots":
            self.robots = values.get("content")
        if tag == "link" and values.get("rel") == "canonical":
            self.canonical = values.get("href")
        for attr in ("href", "src"):
            if attr in values:
                self.links.append(values[attr])


def check(directory, release=False):
    actual = {str(p.relative_to(directory)) for p in directory.rglob("*") if p.is_file()}
    assert actual == FILES, {"missing": sorted(FILES - actual), "unexpected": sorted(actual - FILES)}
    documents = {}
    for name in sorted(n for n in FILES if n.endswith(".html")):
        text = (directory / name).read_text()
        doc = Document()
        doc.feed(text)
        assert doc.h1 == 1 and "{{" not in text, name
        assert "Email setup in progress" not in text, name
        expected_robots = "index,follow" if release and name != "404.html" else "noindex,nofollow"
        assert doc.robots == expected_robots, name
        if name == "404.html":
            assert doc.canonical is None, "404 must not canonicalize to a valid page"
        else:
            route = "/" if name == "index.html" else "/" + name.split("/")[0] + "/"
            assert doc.canonical == "https://teleprompterpal.com" + route, name
        if name in ("privacy/index.html", "support/index.html"):
            assert doc.links.count("mailto:contact@teleprompterpal.com") == 1, name
        assert ("These pages are not published." in text) == (not release), name
        documents[name] = doc
    for name, doc in documents.items():
        for link in doc.links:
            target = urlsplit(urljoin("https://bundle.local/" + name, link))
            if target.netloc != "bundle.local" or target.scheme != "https":
                continue
            path = unquote(target.path).lstrip("/")
            if not path or path.endswith("/"):
                path += "index.html"
            assert path in FILES, (name, link)
            if target.fragment:
                assert path in documents and unquote(target.fragment) in documents[path].ids, (name, link)
    headers = (directory / "_headers").read_text()
    assert headers.startswith("/*\n")
    for setting in ("frame-ancestors 'none'", "X-Content-Type-Options: nosniff", "X-Frame-Options: DENY",
                    "Referrer-Policy: no-referrer", "Permissions-Policy: camera=(), microphone=(), geolocation=()",
                    "Strict-Transport-Security: max-age=31536000",
                    "Cache-Control: public, max-age=0, must-revalidate, no-transform"):
        assert setting in headers, setting
    assert ("X-Robots-Tag: noindex" in headers) == (not release)
    for line in (directory / "_redirects").read_text().splitlines():
        source, destination, status = line.split()
        assert status == "301" and source != destination
        assert destination in ("/privacy/", "/support/")
    robots = (directory / "robots.txt").read_text()
    assert ("Allow: /" if release else "Disallow: /") in robots
    return {"directory": str(directory.resolve()), "mode": "release" if release else "local draft",
            "files": len(actual), "html_documents": len(documents), "links_and_anchors": "passed",
            "headers_and_redirects": "passed", "email": "contact@teleprompterpal.com",
            "network_checks": "not performed", "deployed": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, default=ROOT / "dist")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    print(json.dumps(check(args.directory, args.release), indent=2))
