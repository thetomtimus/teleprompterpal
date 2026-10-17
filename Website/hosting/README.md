# Historical Cloudflare Pages hosting

**Superseded by Vercel on October 17, 2026.** Current deployment instructions are in [the marketing README](../../Marketing/README.md). The Cloudflare Pages project below remains available for rollback.

**Original publication October 17, 2026**, after the owner requested publication through Cloudflare. This publishes the privacy/support website only. The iPhone app and TestFlight package are unchanged.

| Setting | Verified state |
| --- | --- |
| Provider / mode | Cloudflare Pages Free, Direct Upload of static assets |
| Project | `teleprompterpal-legal` |
| Production branch | `main` |
| Current deployment | `7118a436-52ba-4d1a-a5fd-edd83d0e07ad` |
| Deployment URL | https://7118a436.teleprompterpal-legal.pages.dev |
| Pages hostname | https://teleprompterpal-legal.pages.dev |
| Custom domain | `teleprompterpal.com`, Active with SSL enabled |
| Public pages | https://teleprompterpal.com/privacy/ and https://teleprompterpal.com/support/ |
| Production files | `Website/release/`, nine files |
| Last uploaded ZIP | `Website/teleprompterpal-pages-2026-10-17-v2.zip` |
| Git integration / automatic deployment | None |
| Web Analytics | Disabled in the project dashboard |
| Functions / bindings / secrets / contact form / log export | None added; bundle contains only static assets |
| Mail records | All eight prior Google mail/verification records unchanged |

The machine-readable record is [plan.json](plan.json). No credentials are stored here. Screenshots, observed settings, prior DNS, release hashes and HTTP checks are retained in [publication evidence](../../docs/validation/2026-10-17-cloudflare-publication-results.md).

## Files and response behavior

Upload only the generated release bundle: root/privacy/support HTML, top-level 404 page, stylesheet, SVG icon, robots.txt, `_headers` and `_redirects`. The local checker rejects unexpected files. Never upload the repository, source/configuration, app package, provisioning data or documentation.

[_headers](_headers) supplies CSP, MIME/frame protection, referrer and web-permission restrictions, HSTS and cache directives. HSTS applies to the current hostname, without preload or includeSubdomains. `no-transform` keeps the public contact address readable and clickable without an injected email-decoding script. Cloudflare [documents this behavior](https://developers.cloudflare.com/waf/tools/scrape-shield/email-address-obfuscation/). No account security protection was disabled to fix the contact links.

HTML uses `max-age=0, must-revalidate, no-transform`; Cloudflare's custom-domain CDN currently supplies a four-hour max-age for static assets. Missing routes receive `no-store`. The checker accepts these observed provider behaviors while requiring exact page/asset bytes and the security headers. The [headers documentation](https://developers.cloudflare.com/pages/configuration/headers/) describes the static response rules.

[_redirects](_redirects) supplies the slash routes and legacy privacy/support aliases. Unknown nested URLs return the styled top-level `404.html` with HTTP 404, noindex metadata and root-relative recovery links. HTTP redirects to HTTPS. The live acceptance record verifies these outcomes, rather than inferring them from local files.

Cloudflare can process IP addresses, request/traffic details and browser/device data for delivery and protection. The published policy acknowledges essential security cookies and provider-specific retention purposes/legal obligations. No fixed provider retention period is claimed. Ordinary checked responses contained no Set-Cookie or injected scripts, which does not rule out conditional challenges or cookies for other traffic.

## Future authorized updates

1. Edit the sources/settings, then run the draft and release builds/checks documented in [the website README](../README.md). Reconcile the policy if app or host behavior changes.
2. Create a ZIP of the **contents** of `Website/release/`, with the nine allowed files at its root. Retain a SHA-256 manifest and the prior deployment ID.
3. In the existing project's **Create deployment** flow, select Production and upload the checked ZIP. Deploy only when the owner has authorized that content update. The [Direct Upload guide](https://developers.cloudflare.com/pages/get-started/direct-upload/) covers the workflow; this project is not Git-integrated.
4. Verify the new production deployment ID, public privacy/support routes, TLS, contact link, redirects, missing-page status and scripts/cookies/headers. Use `Website/check_live.py` for the repeatable HTTP checks and inspect the rendered pages.
5. Record the new deployment ID/hash evidence. Use the reviewed Pages rollback flow if a release needs reversal. Do not roll back to the initial deployment below without accounting for its broken contact-link transformation.

The apex was associated through Pages' [Custom domains flow](https://developers.cloudflare.com/pages/configuration/custom-domains/) before its proxied CNAME was added. The only new record points `teleprompterpal.com` at `teleprompterpal-legal.pages.dev`. Preserve MX, SPF, DKIM and verification records and nameservers during future migrations. No `www` hostname is configured.

The initial deployment `6128ba96-824d-45cc-a620-5566a3929512` exposed Cloudflare email obfuscation under the site's script-free CSP. The current second deployment adds the no-transform directive and passes the live checks. The two deployments and both release manifests are retained as history.

Publishing this site does not authorize App Store Connect registration, Apple upload, TestFlight review or tester invitations. Purchases remain disabled, recording has no app-imposed limit and remaining camera checks are deferred.
