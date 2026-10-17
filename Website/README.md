# teleprompterpal.com privacy and support pages

Published October 17, 2026 on **Cloudflare Pages**, under **Second Wind, LLC, United States**:

- [Privacy policy](https://teleprompterpal.com/privacy/), effective October 17, 2026.
- [Support](https://teleprompterpal.com/support/).
- [Site directory](https://teleprompterpal.com/).

The owner confirmed that **contact@teleprompterpal.com** sends and receives email. The deployment preserved all eight existing Google mail/verification records and added only the apex web CNAME. No mailbox or nameserver was changed. See the [publication results](../docs/validation/2026-10-17-cloudflare-publication-results.md).

The site uses plain HTML/CSS, native disclosure controls, system fonts and the project's original SVG icon. It has no scripts, forms, analytics tags or application cookies. Pages Web Analytics is disabled. Cloudflare still processes delivery/security request data and may use essential security cookies; the policy links to its practices without inventing a fixed retention period.

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

For local review, serve `Website/dist/` on loopback. A basic file server does not implement Cloudflare's headers, redirects or HTTPS. After an authorized deployment, run the read-only live checker:

```sh
python3 Website/check_live.py teleprompterpal.com --evidence /tmp/teleprompterpal-live-check.json
```

This checks public content against the current release bytes, TLS, status codes, redirects, MIME, security/cache headers and ordinary cookie/script injection. Conditional security challenges are outside that check. Cloudflare supplies `no-store` on missing routes and may raise static-asset max-age; the HTML remains revalidated and untransformed.

## Updates and scope

Use the existing **teleprompterpal-legal** Direct Upload project for future authorized content changes. Upload only the checked release directory or its ZIP. Follow [the hosting handoff](hosting/README.md), retain the uploaded hashes and verify the actual public URLs afterward. Git automatic deployment is not configured.

The current installed app and local distribution package remain **0.6.5/build 25**. A later app update can add links to these now-live pages. This website publication did not update the phone, register an App Store app, upload to TestFlight or invite testers. Purchases remain disabled, recording has no app-imposed duration/file-size cap and physical camera checks remain deferred.
