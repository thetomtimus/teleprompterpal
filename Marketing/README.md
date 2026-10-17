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

The build runs strict Astro/TypeScript checks and emits a static website to `dist/`. Astro 7.4, native CSS and small browser scripts; no React runtime or external font requests.

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

## Publication

This is an **unpublished local implementation** with `noindex, nofollow` metadata. No deployment, DNS or email settings were changed. The existing live privacy/support website in `../Website/` and native app files are preserved. Privacy and support links lead to the current live pages.

Before an authorized production launch, use the real install destination, check the access copy, set production indexing/canonical/social metadata, and preserve the existing `/privacy/` and `/support/` routes. The current `og:image` points at the future marketing asset path, which becomes available only when this build is deployed.

## Validation

The current production build passes `astro check` and `astro build` with zero diagnostics. Dependency audit reports zero vulnerabilities. Browser interaction checks, responsive captures and the independent finish review are retained locally in `.impeccable/review/`, which is excluded from Git. The measured reference values and asset provenance are committed under `docs/`.
