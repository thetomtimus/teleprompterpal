#!/usr/bin/env python3
"""Build local review pages; --release validates required publication inputs but never deploys."""
from pathlib import Path
from html import escape
from datetime import date
import argparse
import json
import re
import shutil

ROOT = Path(__file__).resolve().parent
SECTIONS = {
    "privacy": [
        ("overview", "What this covers"), ("local-library", "Your local library"),
        ("permissions", "Permissions"), ("diagnostics", "Local diagnostics"),
        ("exports-backups", "Exports and backups"), ("support-information", "Support messages"),
        ("deletion", "Data retention and deletion"), ("website", "These web pages"),
        ("contact", "Privacy questions"), ("changes", "Policy changes")],
    "support": [("start", "Your first recording"), ("recording", "Recording and scrolling"),
        ("edit-export", "Edit, export and save"), ("scripts-data", "Scripts and your library"),
        ("contact", "Contact support")]
}


def contents(page):
    return "<ul>" + "".join(f'<li><a href="#{anchor}">{label}</a></li>' for anchor, label in SECTIONS[page]) + "</ul>"


def build(release=False):
    config = json.loads((ROOT / "site.json").read_text())
    email = config["support_email"]
    valid_email = isinstance(email, str) and re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email)
    valid_email = valid_email and not email.lower().endswith(("@example.com", ".invalid", ".test"))
    email_verified = config.get("support_email_verified") is True
    missing = []
    if not valid_email or not email_verified:
        missing.append("a support_email verified for sending and receiving")
    if not config["hosting_disclosure"]:
        missing.append("the actual hosting provider and its logging/retention disclosure")
    if config.get("hosting_verified") is not True:
        missing.append("verification of the actual hosting configuration and final disclosure")
    if not config["effective_date"]:
        missing.append("the publication effective_date")
    if release and missing:
        raise SystemExit("Release pages were not generated. Still needed: " + "; ".join(missing))
    out = ROOT / ("release" if release else "dist")
    out.mkdir(exist_ok=True)
    (out / "assets").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "assets/site.css", out / "assets/site.css")
    shutil.copy2(ROOT.parent / "Scripts/iphone-beta-icon.svg", out / "assets/app-icon.svg")
    headers = (ROOT / "hosting/_headers").read_text()
    if not release:
        headers += "  X-Robots-Tag: noindex, nofollow\n"
    (out / "_headers").write_text(headers)
    shutil.copy2(ROOT / "hosting/_redirects", out / "_redirects")
    if release:
        date.fromisoformat(config["effective_date"])
        document_date = "Effective " + date.fromisoformat(config["effective_date"]).strftime("%B %d, %Y").replace(" 0", " ")
    else:
        document_date = "Draft updated " + date.fromisoformat(config["draft_updated"]).strftime("%B %d, %Y").replace(" 0", " ")
    contact = (f'<p>Email <a href="mailto:{escape(email, quote=True)}">{escape(email)}</a> for support or privacy requests.</p>'
        if valid_email else '<div class="pending-contact"><strong>Contact email pending setup</strong><p>The support and privacy mailbox will be added before these pages are published. This local review draft cannot receive messages.</p></div>')
    if valid_email and not email_verified:
        contact += '<div class="pending-contact"><strong>Email setup in progress</strong><p>This address is being configured. Sending and receiving have not yet been verified; please wait until setup is complete before sending a request.</p></div>'
    hosting = config["hosting_disclosure"] or "The hosting provider and its logging and retention practices will be identified before these pages are published."
    values = {key: escape(str(config[key])) for key in ("app_name", "operator", "country")}
    values.update(document_date=escape(document_date), contact=contact, hosting_disclosure=escape(hosting))
    draft = '' if release else '<div class="draft-notice"><strong>Local review draft.</strong> These pages are not published.</div>'
    robots = "index,follow" if release else "noindex,nofollow"
    for page in SECTIONS:
        title = "Privacy policy" if page == "privacy" else "Support"
        text = (ROOT / f"src/{page}.html").read_text()
        page_values = values | {"mobile_contents": '<details class="mobile-contents"><summary>On this page</summary>' + contents(page) + '</details>'}
        for key, value in page_values.items():
            text = text.replace("{{" + key + "}}", value)
        assert "{{" not in text, page
        if release:
            text = text.replace('../support/index.html', '/support/').replace('../privacy/index.html', '/privacy/')
        html = frame(config, page, title, text, draft, robots, '../', clean_urls=release)
        (out / page).mkdir(exist_ok=True)
        (out / page / "index.html").write_text(html)
    index = '<div class="directory"><h1>Privacy and support</h1><p class="lead">Information for the current iPhone beta of teleprompterpal.com.</p><ul><li><h2><a href="support/index.html">Support</a></h2><p>Recording, scrolling, exports and your library.</p></li><li><h2><a href="privacy/index.html">Privacy policy</a></h2><p>Local content, permissions, diagnostics and your choices.</p></li></ul></div>'
    if release:
        index = index.replace('support/index.html', '/support/').replace('privacy/index.html', '/privacy/')
    (out / "index.html").write_text(frame(config, '', 'Privacy and support', index, draft, robots, '', clean_urls=release))
    not_found = '<div class="directory"><h1>Page not found</h1><p class="lead">Find help with the app or read how your information is handled.</p><ul><li><h2><a href="/support/">Support</a></h2><p>Recording, scrolling, exports and your library.</p></li><li><h2><a href="/privacy/">Privacy policy</a></h2><p>Local content, permissions, diagnostics and your choices.</p></li></ul></div>'
    (out / "404.html").write_text(frame(config, '', 'Page not found', not_found, draft, 'noindex,nofollow', '/', clean_urls=True, not_found=True))
    (out / "robots.txt").write_text("User-agent: *\nDisallow: /\n" if not release else "User-agent: *\nAllow: /\n")
    print(json.dumps({"output": str(out), "release": release, "published": False, "missing_publication_inputs": missing}, indent=2))


def frame(config, page, title, content, draft, robots, prefix, clean_urls=False, not_found=False):
    nav = ''.join(f'<a href="{("/" + route + "/") if clean_urls else (prefix + route + "/index.html")}"' + (' aria-current="page"' if route == page else '') + f'>{label}</a>' for route, label in [('support', 'Support'), ('privacy', 'Privacy')])
    toc = '<aside class="toc" aria-label="On this page"><p>On this page</p>' + contents(page) + '</aside>' if page else ''
    body = f'<div class="layout">{toc}<main id="main" tabindex="-1">{content}</main></div>' if page else f'<main id="main" tabindex="-1">{content}</main>'
    canonical = config['site_url'].rstrip('/') + ('/' + page + '/' if page else '/')
    canonical_tag = '' if not_found else f'<link rel="canonical" href="{escape(canonical, quote=True)}">'
    home = '/' if clean_urls else prefix + 'index.html'
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{escape(title)} | {escape(config['app_name'])}</title>
<meta name="description" content="{escape(title)} for the current teleprompterpal.com iPhone beta, operated by Second Wind, LLC.">
<meta name="robots" content="{robots}"><meta name="referrer" content="no-referrer">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'">
{canonical_tag}<link rel="icon" href="{prefix}assets/app-icon.svg" type="image/svg+xml">
<link rel="stylesheet" href="{prefix}assets/site.css"></head><body>
<a class="skip-link" href="#main">Skip to content</a>
<header class="site-header"><a class="brand" href="{home}"><img src="{prefix}assets/app-icon.svg" alt="" width="32" height="32">{escape(config['app_name'])}</a><nav class="site-nav" aria-label="Main">{nav}</nav></header>
{draft}{body}
<footer class="site-footer"><p>{escape(config['operator'])} · {escape(config['country'])}</p><nav aria-label="Footer">{nav}</nav></footer>
</body></html>'''


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', action='store_true', help='Require publication inputs and create local release/ output; never uploads.')
    build(parser.parse_args().release)
