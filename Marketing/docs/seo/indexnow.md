# IndexNow publishing notifications

Run from this website’s project directory after a production deployment is READY and the new content is live. The command is a dry run unless `--submit` is supplied. Use only explicit, newly added or substantively updated canonical URLs. Do not repeat unchanged URLs, cosmetic-only changes, drafts or the noindex utility reader.

```sh
python3 scripts/submit_indexnow.py https://teleprompterpal.com/about/ --out /absolute/private-output/dry-run.json
python3 scripts/submit_indexnow.py https://teleprompterpal.com/about/ --submit --out /absolute/private-output/receipt.json
```

Pass several changed URLs in the same invocation. This is an owner-run post-deployment command, not a background schedule or build-time submission.

The script verifies the exact production key file, sitemap membership, HTTP 200, matching canonical and absence of noindex before sending a single POST to the global endpoint. It rejects another domain, query strings, fragments and credentials. It saves response status without automatically retrying. Keep receipts outside public output directories.

HTTP 200 records successful receipt. HTTP 202 records receipt with key validation pending. Neither result establishes crawling, indexing or rankings. Google Search Console requests remain a separate workflow. Keep canonical sitemaps in place.

The key file is intentionally publicly hosted to verify this domain under the protocol. It is not a Vercel, Google or Microsoft account credential. Do not reuse this domain-scoped key for another website.

Sources checked October 21, 2026:
- https://www.indexnow.org/documentation
- https://www.indexnow.org/faq
- https://www.bing.com/indexnow/getstarted
