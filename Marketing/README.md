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
- `src/components/QRCode.astro`: QR SVG generated at build time. There is no QR service or tracking redirect.
- `docs/detail-reference.md`: exact observed reference values and intentional adaptations.
- `docs/asset-provenance.json`: sources and hashes for the approved icon, fictional presenter and actual app screenshots.
- `DESIGN.md` and `.impeccable/design.json`: the implemented marketing design system.

The app is currently in **private beta**. The CTA and both QR codes open a beta-access email to `contact@teleprompterpal.com`; they do not send an email automatically or imply a public download. The QR has been independently decoded at its 136px desktop display size. When an App Store/TestFlight link is available, update the URL and access wording in `src/data/site.ts`, update the access FAQ and QR wording, and rebuild. Do not invent a public installation URL.

## Interactions

- Browser rehearsal: play/pause, restart, pace and text size. Space toggles playback when the reader is focused. Scrolling out of view or leaving the tab pauses it. Scrolling only starts on explicit input, including under Reduce Motion.
- Crop demonstration: 9:16, 1:1, 16:9 and 4:5, with mutually exclusive accessible pressed states.
- Native disclosure FAQ and compact mobile navigation, with Escape to close and return focus.
- Desktop floating QR; a second QR remains available in the closing section on mobile. All QR and CTA destinations match.

The camera/editing previews and crop demonstration are clearly labeled illustrative. They use the project's existing fictional presenter. The Scripts/editor/settings images are actual Simulator captures. The website never accesses a camera or microphone.

## Vercel deployment

The Vercel project builds `Marketing/` from the repository's `main` branch. Enable access to source files outside the root directory so the build can read `Website/` and its original icon in `Scripts/`. Use Node 24.x, `npm ci`, `npm run build`, and output directory `dist/`. No Vercel adapter or runtime functions are needed for this static site.

`vercel.json` preserves the privacy/support aliases and supplies response headers. Browser scripts are emitted as separate same-origin assets for the Content Security Policy. The native apps and source documentation are never part of the public build output.

`scripts/prepare-deployment.mjs` builds and checks the authoritative legal pages, includes `/privacy/`, `/support/`, their assets and a custom 404, and adds `robots.txt` and `sitemap.xml`. Development and Vercel previews remain noindex; production declares the apex canonical URL and allows indexing.

Target domain: https://teleprompterpal.com/. Vercel serves the website; Cloudflare remains the DNS provider. Preserve all mail and verification records when changing the apex web record. The previous Cloudflare Pages deployment is retained for rollback.

The approved CTA and QR still request private-beta access by email. No App Store or public TestFlight link is configured. The approved hero voice-tracking description is launch positioning for planned functionality; the current iPhone beta still uses manual scrolling controls.

## Validation

The current production build passes `astro check` and `astro build` with zero diagnostics. Dependency audit reports zero vulnerabilities. Browser interaction checks, responsive captures and the independent finish review are retained locally in `.impeccable/review/`, which is excluded from Git. The measured reference values and asset provenance are committed under `docs/`.
