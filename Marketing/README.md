# Teleprompter Pal · Astro marketing site

A complete local marketing site for the iPhone app, adapted from the measured design system at [Detail](https://detail.co/).

## Run

Use Node **22.22 or later** and npm.

```sh
npm ci
npm run dev
```

The preview is available at the Local URL printed by Astro. The current review uses [127.0.0.1:4321](http://127.0.0.1:4321/).

```sh
npm run build
npm run preview
```

The build runs strict Astro/TypeScript checks, emits a static website to `dist/`, then builds and includes the existing privacy/support pages from `../Website/`. It requires Python 3 as well as Node. Astro 7.4, native CSS and small browser scripts; no React runtime or external font requests.

## Content and access

- `src/data/site.ts`: product name, metadata, support/policy links, and **one shared CTA/QR destination**.
- `src/pages/index.astro`: page content and the rehearsal/crop interactions.
- `src/styles/global.css`: measured design primitives and responsive layouts.
- `src/content/guides/*.md`: approved guide content, validated by `src/content.config.ts`. Drafts default to hidden; only explicit `draft: false` entries appear in public routes and the guide index.
- `src/pages/guides/`: the guide index and reusable article route. Shared `SiteHeader.astro` and `SiteFooter.astro` expose Guides in desktop/mobile navigation and the footer.
- `src/components/QRCode.astro`: QR SVG generated at build time. There is no QR service or tracking redirect.
- `docs/detail-reference.md`: exact observed reference values and intentional adaptations.
- `docs/asset-provenance.json`: sources and hashes for the approved icon, fictional presenter and actual app screenshots.
- `DESIGN.md` and `.impeccable/design.json`: the implemented marketing design system.

The app is currently in **private beta**. Every early-access CTA and both QR codes lead to the homepage’s `#early-access` email signup. `EarlyAccessForm.astro` sends an email address directly to HubSpot’s public Forms API. It shows success only after HubSpot accepts the submission, retains input on failure, and provides a hosted-form fallback for visitors without JavaScript. No API key, tracking script, server function or local email storage is required. Known referrals from Free Teleprompter Online are retained as fixed source/medium/campaign labels in tab session storage and included in HubSpot’s signup page context. Arbitrary URL parameters, fragments, user content and visitor identifiers are excluded. This identifies a submission’s labeled source; it does not establish a complete reader-to-signup conversion rate or independently verify clicks. The QR encodes the absolute production signup URL.

Emails are saved in the existing Second Wind HubSpot account (portal `247519359`) under **Teleprompter Pal Early Access**, form `d09c4c70-dff9-4a17-be08-8edf1c5b4241`. Open [the signup submissions](https://app-na2.hubspot.com/submissions/247519359/form/d09c4c70-dff9-4a17-be08-8edf1c5b4241/submissions) to view or export them. Contacts are matched by email; repeated signups update the same contact. The form has one required Email field and creates a contact for each new email. Its published **Options → Send submission notifications to** setting emails `thetomtimus@gmail.com` for each signup. There is no automated follow-up email to the person signing up. HubSpot’s free tools support this setup, subject to the account’s contact limits (currently 1,000 for free accounts). No paid upgrade was added. The website privacy policy describes signup storage and removal requests.

The production domain `teleprompterpal.com` must stay registered under HubSpot Settings → Tracking & Analytics → Tracking Code → Advanced Tracking → Additional site domains. HubSpot can return a successful API response while quarantining an unregistered domain’s submissions in the form’s Spam tab. Register a replacement production domain before using it; keep bot filtering on.

When an App Store/TestFlight link is available, update the URL and access wording in `src/data/site.ts`, update the access FAQ and QR wording, and rebuild. Do not invent a public installation URL.

## Interactions

- Browser rehearsal: play/pause, restart, pace and text size. Space toggles playback when the reader is focused. Scrolling out of view or leaving the tab pauses it. Scrolling only starts on explicit input, including under Reduce Motion.
- Crop demonstration: 9:16, 1:1, 16:9 and 4:5, with mutually exclusive accessible pressed states.
- Native disclosure FAQ and compact mobile navigation, with Escape to close and return focus.
- Desktop floating QR; a second QR remains available in the closing section on mobile. All QR and CTA destinations match.

The camera/editing previews and crop demonstration are clearly labeled illustrative. They use the project's existing fictional presenter. The Scripts/editor/settings images are actual Simulator captures. The website never accesses a camera or microphone.

## Vercel deployment

Live at https://teleprompterpal.com/ on the Second Wind Vercel Pro team, project `teleprompterpal`. The project is connected to `thetomtimus/teleprompterpal` on GitHub. Every push to `main` triggers a production build and automatically updates the website when the build succeeds. Other branches produce preview deployments. No Vercel adapter or runtime functions are needed.

For normal updates, run `npm ci` and `npm run build` in `Marketing/` to check the change, then commit and push to `main`. Vercel runs the build again and publishes the result. Failed builds leave the previous working deployment live.

The build also prepares `.vercel/static-release/` with runtime assets and static Vercel configuration for an explicitly requested manual fallback. With the CLI signed in to the intended team:

```sh
vercel deploy .vercel/static-release --prod --project teleprompterpal --scope thetomtimus-gmailcoms-projects --yes
```

Verified Vercel build settings: root directory `Marketing`, Node 24.x, install command `npm ci`, build command `npm run build`, output directory `dist`, and production branch `main`. Access to source files outside the root directory is enabled for `Website/` and `Scripts/`. Production custom-domain assignment is enabled.

`vercel.json` preserves the privacy/support aliases and supplies response headers. Browser scripts are emitted as separate same-origin assets for the Content Security Policy. The native apps and source documentation are never part of the public build output.

`scripts/prepare-deployment.mjs` builds and checks the authoritative legal pages, includes `/privacy/`, `/support/`, their assets and a custom 404, and adds `robots.txt` and `sitemap.xml`. Development and Vercel previews remain noindex; production declares the apex canonical URL and allows indexing.

Production domain: https://teleprompterpal.com/. The www hostname redirects to the apex. Vercel serves the website; Cloudflare remains the DNS provider. Preserve all mail and verification records when changing the apex web record. The previous Cloudflare Pages deployment is retained for rollback.

Cloudflare Web Analytics is enabled with manual JS snippet installation. The production post-build step adds its public beacon to every generated HTML page, including guides, privacy, support and 404; Vercel previews and the standalone legal review bundle are excluded. The response CSP and the copied legal pages' meta CSP allow only the Cloudflare script and measurement endpoint needed for this service. The website privacy policy discloses the service. View [the bot-filtered report](https://dash.cloudflare.com/b09b147e2f7b97378b35d5eac2c93d0a/web-analytics/overview?siteTag~in=b421b846da344a3089419b126a5dcad1&excludeBots=Yes), with **Exclude bots equals Yes**. Visits are an estimate of traffic, not a count of identified people, and data starts after installation.

The CTA and QR collect private-beta signup emails through the form. No App Store or public TestFlight link is configured. The homepage title, H1 and description target the iPhone beta. Scrolling is manual; the FAQ explicitly distinguishes it from speech-following. Mac access is described as planned for later. The FAQ and footer link to the full free browser teleprompter.

## Publishing guides

The owner approved the first guide on October 19, 2026. Future daily articles remain reviewable drafts outside the public source tree until approved. Copy only approved content into `src/content/guides/` with `title`, `headline`, `description`, `date`, optional short `breadcrumb`, and explicit `draft: false`. The page template supplies the H1, so the Markdown body starts with the opening paragraph. Preserve the approved canonical slug and original publication date.

The index and article paths are generated from that collection. The post-build script discovers generated page routes for the sitemap, excludes the 404, verifies production canonicals and external-script CSP compatibility, and adds the existing analytics beacon. No manual sitemap URL list is required for later articles. Publish the approved article with its relevant inbound/contextual links and check the exact live URLs after Vercel finishes. A sitemap submission or indexing request helps discovery; it is not proof that Google has indexed a page.

## Validation

The current production build passes `astro check` and `astro build` with zero diagnostics. Dependency audit reports zero vulnerabilities. Browser interaction checks, responsive captures and the independent finish review are retained locally in `.impeccable/review/`, which is excluded from Git. The measured reference values and asset provenance are committed under `docs/`.

October 19 SEO corrections: shared iPhone metadata, truthful manual-scrolling and Mac-access FAQs, contextual browser-tool links and allowlisted signup referral context. Run `node --test tests/signup-context.test.ts` with Node 24 to verify campaign retention, storage-denial recovery and private-parameter exclusion. Browser QA uses a local signup stub; no test contact is created by that check.
