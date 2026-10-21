#!/usr/bin/env python3
"""Notify IndexNow after production deployment. Dry-run unless --submit is passed."""
import argparse
from datetime import datetime, timezone
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler
import xml.etree.ElementTree as ET

ENDPOINT = 'https://api.indexnow.org/indexnow'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


def validate_url(url, host):
    parsed = urlsplit(url)
    if (parsed.scheme != 'https' or parsed.netloc != host or parsed.query
            or parsed.fragment or parsed.username or parsed.password):
        raise ValueError('Use an exact HTTPS production URL without query, fragment or credentials.')
    return url


class Page(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.canonicals = []
        self.noindex = False
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'link' and 'canonical' in attrs.get('rel', '').lower().split():
            self.canonicals.append(attrs.get('href'))
        if tag == 'meta' and attrs.get('name', '').lower() in ('robots', 'bingbot'):
            tokens = re.split(r'[\s,]+', attrs.get('content', '').lower())
            self.noindex = self.noindex or 'noindex' in tokens or 'none' in tokens


def get(opener, url):
    with opener.open(Request(url, headers={'User-Agent': 'Owner-IndexNow-Publish-Check/1.0'}), timeout=30) as response:
        if response.status != 200 or response.url != url:
            raise ValueError('Production preflight did not return an exact HTTP 200: ' + url)
        return response.read(), response.headers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('urls', nargs='+', help='Only newly added or substantively updated public URLs.')
    parser.add_argument('--submit', action='store_true', help='Send one POST after all production preflights pass.')
    parser.add_argument('--out', type=Path, help='Save a dated JSON receipt outside the public directory.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / 'indexnow.json').read_text())
    host = config['host']
    key_file = config['key_file']
    if not re.fullmatch(r'[a-f0-9]{32}\.txt', key_file):
        raise ValueError('Unexpected IndexNow key filename.')
    key = (root / config['public_dir'] / key_file).read_text().strip()
    if key != key_file[:-4]:
        raise ValueError('Key contents do not match the filename.')
    urls = list(dict.fromkeys(validate_url(url, host) for url in args.urls))
    if not 1 <= len(urls) <= 10000:
        raise ValueError('Submit between 1 and 10,000 changed URLs.')
    origin = 'https://' + host
    key_location = origin + '/' + key_file
    opener = build_opener(NoRedirect())
    live_key, _ = get(opener, key_location)
    if live_key.decode('utf-8-sig').strip() != key:
        raise ValueError('The production key file does not match this checkout.')
    sitemap, _ = get(opener, origin + '/sitemap.xml')
    inventory = {element.text for element in ET.fromstring(sitemap).findall('.//{*}loc')}
    for url in urls:
        if url not in inventory:
            raise ValueError('URL is outside the public canonical sitemap: ' + url)
        html, headers = get(opener, url)
        page = Page(html.decode('utf-8'))
        if page.canonicals != [url] or page.noindex or re.search(r'\b(noindex|none)\b', headers.get('X-Robots-Tag', ''), re.I):
            raise ValueError('URL has a nonmatching canonical or noindex directive: ' + url)
    receipt = {'checked_at': datetime.now(timezone.utc).isoformat(), 'host': host,
               'endpoint': ENDPOINT, 'key_location': key_location, 'urls': urls,
               'production_preflight': 'passed', 'submitted': False,
               'meaning': 'Notification receipt is not proof of crawling, indexing or ranking.'}
    if args.submit:
        payload = json.dumps({'host': host, 'key': key, 'keyLocation': key_location, 'urlList': urls}).encode()
        request = Request(ENDPOINT, data=payload, method='POST',
                          headers={'Content-Type': 'application/json; charset=utf-8',
                                   'User-Agent': 'Owner-IndexNow-Publish-Notify/1.0'})
        try:
            with opener.open(request, timeout=30) as response:
                status, body = response.status, response.read()
            receipt.update(submitted=True, http_status=status,
                           response_body=body.decode('utf-8', errors='replace')[:500],
                           key_validation='pending' if status == 202 else 'accepted' if status == 200 else 'unconfirmed')
        except HTTPError as error:
            receipt.update(http_status=error.code, error=error.read().decode('utf-8', errors='replace')[:500])
        except URLError as error:
            receipt.update(error=str(error.reason), transport_result='No response; acceptance unconfirmed. Do not retry automatically.')
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
    if args.submit and receipt.get('http_status') not in (200, 202):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
