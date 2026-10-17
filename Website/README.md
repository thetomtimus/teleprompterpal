# teleprompterpal.com privacy and support pages

Published October 17, 2026 under **Second Wind, LLC, United States**. These pages now ship with the Astro marketing site on **Vercel**; Cloudflare provides DNS:

- [Privacy policy](https://teleprompterpal.com/privacy/), effective October 17, 2026.
- [Support](https://teleprompterpal.com/support/).
- [Marketing homepage](https://teleprompterpal.com/).

The owner confirmed that **contact@teleprompterpal.com** sends and receives email. The Vercel migration preserved all eight existing Google mail/verification records, changed the apex web CNAME and added a www redirect hostname. No mailbox or nameserver was changed. See the [publication results](../docs/validation/2026-10-17-cloudflare-publication-results.md).

These policy and support pages use plain HTML/CSS, native disclosure controls, system fonts and the project's original SVG icon. They contain no scripts, forms, analytics tags or application cookies. The Astro homepage uses local browser scripts for its demos and self-hosted fonts. Vercel processes delivery/security request data; the policy identifies the providers without inventing a fixed retention period.

## Edit and check

- Privacy source: `src/privacy.html`.
- Support source: `src/support.html`.
- Operator, contact, effective date and hosting disclosure: `site.json`.
- Presentation: `assets/site.css`; wrapper/navigation: `build.py`.
- Response headers, aliases and deployment record: `hosting/`.

From the repository root:

```sh
python3 Website/build.py
python3 Website/check.py
python3 Website/build.py --release
python3 Website/check.py Website/release --release
```

The default build produces `Website/dist/`, an explicitly unpublished/noindex **local review copy**. This does not describe the publication state of the live site. The release build produces `Website/release/`, the nine-file publishable bundle. Neither command uploads anything. Release generation checks the configured email/hosting verification flags and effective date; it does not itself verify a provider or certify legal compliance.

For local review, serve `Website/dist/` on loopback. A basic file server does not implement production response headers, redirects or HTTPS.

## Production updates

Build and deploy through [the Astro marketing site](../Marketing/README.md). Its build includes these authoritative privacy/support sources, assets, aliases and 404 page. Uploading `Website/release/` alone would replace the marketing homepage, so do not use the old Cloudflare upload workflow for current releases.

`check_live.py` is the historical checker for the original Cloudflare legal-only release. It expects the old directory homepage and headers and is not the acceptance checker for the combined Vercel site. Current launch evidence is retained in `docs/validation/vercel-launch-2026-10-17/`: all 20 public build files match exactly and seven URL/HTTPS/www redirects pass.

The previous Cloudflare Pages deployment is retained for rollback. These hosting changes do not publish or modify an iPhone or Mac app release, App Store listing or TestFlight distribution.
