---
version: 1
slug: "website-languages"
primary_target: "src/components/LanguageChooser.astro"
related_targets: ["src/styles/global.css", "public/assets/legal-languages.css", "public/assets/language-chooser.js", "src/i18n/config.mjs", "scripts/localize.mjs", "docs/languages.md"]
---

# Teleprompter Pal website languages

Documented October 23, 2026. Mode: Operate within the existing Persuade pages. This ordinary code-led extension adds language navigation and complete homepage/pricing translations to the Teleprompter Pal website. The incumbent marketing identity remains authoritative. This record documents the reviewed implementation and recorded local build evidence; it does not confirm live publication.

## Direction contract

THESIS: Let visitors choose a readable version of the product and its pricing, with a language control at the top and another at the very bottom.

OWN-WORLD: Preserve the self-hosted Figtree, near-black canvas, lavender links and focus, violet actions, approved wordmark and device imagery. Use native language names without flags.

STORY: Choose English, Español, Deutsch, Français or Português (Brasil); read home and pricing in that language; recognize links that lead to English-only content.

FIRST VIEWPORT: Retain the shared header and product hero. Place a compact globe, current-language abbreviation and caret beside the header actions. On narrow screens, keep the chooser beside the mobile navigation. Put all five language links below the footer's existing final content.

FORM: A native disclosure with ordinary destination links extends the existing navigation. Choosing a language preserves home or pricing when an equivalent exists. No new visual world or generated artwork is introduced.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

For this ordinary extension, the finish contract preserves the incumbent `DESIGN.md` and `.impeccable/design.json` and records the comparison here. No new shipping raster was created.

## Coverage and navigation

English remains at `/` and `/pricing/`. Spanish, German, French and Brazilian Portuguese use `/es/`, `/de/`, `/fr/` and `/pt-br/`, with a corresponding `pricing/` route under each prefix. The Brazilian Portuguese language tag is `pt-BR`.

Guides, comparisons, tools, About, privacy and support remain English. Their chooser identifies the other-language destinations as homepages. The English link retains the current English page. On translated home/pricing pages, links to English-only destinations carry an English-language label and `hreflang="en"`; compact desktop navigation uses `(EN)`. Existing native app screenshots remain in English and their caption identifies this. Website translations do not establish language support in the iPhone app.

The header uses native `details` and `summary`, and the destinations remain ordinary anchors. The current locale is marked with `aria-current`, a lavender treatment and a check in the header disclosure. The header summary has an accessible language label; each language link declares its own `lang`. Keyboard focus uses the existing visible lavender outline. Escape closes an open chooser and restores focus to its summary. Outside click closes it. Opening mobile navigation closes the language chooser, and opening the chooser closes mobile navigation.

## Implemented composition

The marketing chooser has a compact semibold summary (13px, 44px minimum height) and an anchored dark menu with softly rounded corners (16px). The menu is 246px wide with a viewport-relative maximum width, and its rows have a 46px minimum height. Its tonal fill, quiet border, shadow and lavender selection reuse the incumbent navigation language. Footer language links form a wrapping row below a quiet divider, with 44px minimum hit areas and an underlined current language.

Desktop navigation uses 14px labels and 18px gaps. At 1279px and below it yields to the mobile disclosure. Below 600px the compact header CTA is hidden so the wordmark, language control and mobile navigation fit together. Below 375px the chooser omits the globe while retaining its language abbreviation, caret and minimum width. Translated home headings use a local `clamp(40px, 5.1vw, 70px)` override. Demo buttons can wrap, and the mobile privacy link can wrap, accommodating longer translated strings without changing the global type scale.

Privacy and support preserve their existing page system. Their injected language control uses a 44px summary, a dark menu with 12px corners, and the same five native names. At 760px and below the existing page navigation occupies its own row. The footer's language links wrap beneath a divider. The shared dismissal script serves both marketing and legal page families.

## Content and search behavior

`scripts/localize.mjs` translates the rendered English homepage and pricing page from saved catalogs. It handles visible text, accessibility labels, metadata and interactive messages; scripts, styles, SVG content and explicitly protected content are excluded. Eligible internal links and pricing QR codes point to the selected locale. Each page receives its own canonical URL and document language, reciprocal language alternates and an English `x-default`. The existing post-build process inventories the localized routes in the sitemap.

Exact English source strings are translation keys. New or changed keys stop the build until all four catalogs are updated. Validation rejects HTML in translations and checks protected product, price, percentage and MP4 tokens. Layout changes can rebuild existing translations without a translation-service request. `docs/languages.md` records the update process, release checks and limitations. No runtime translator, automatic redirect or language-preference cookie is introduced.

## Finish evidence and limits

The finish review is recorded in `.impeccable/review/languages/finish-review.md`. Its final disposition is **ship at the verdict-pass scope**: the reviewer scored the sole material finding, language-menu dismissal on privacy and support, resolved. The initial full review and its evidence are retained in that record. This documentation does not broaden the fix verdict into a new whole-site review.

Evidence checked for this record:

- Read the component, final language section of the global stylesheet, legal styles, shared chooser script, locale configuration, localization script, product/design records and publishing guide.
- Read `layout-results.json`: five locales at 1440px, 1024px, 390px and 320px, with no recorded document overflow or header overlap and five language links per case.
- Read `interactions.json`: localized German rehearsal/signup feedback and German/French monthly billing states, with no recorded page errors. Signup was stubbed. The French desktop floating QR caption extends 2px past the viewport without document overflow; the reviewer recorded this as nonblocking.
- Read `chooser-preview.json` and `chooser-production.json`: Escape, summary focus restoration and outside-click dismissal passed for `/de/`, `/es/pricing/`, `/privacy/` and `/support/`, with no recorded CSP violations or JavaScript errors. These are local preview/production-build modes, not evidence of a live deployment.
- Viewed `de-1440-menu.png`, `de-390-menu.png`, `de-390-footer.png` and `production-privacy-chooser.png`. They show the expected native names, current language, mobile wrapping and retained page identity. The finish review lists the wider capture set inspected by its reviewer.
- Read `production-build.log`: recorded Astro diagnostics report zero errors, warnings or hints, and generation checked 220 source strings across two pages and five locales. The finish reviewer also records the parent's passing final build and six i18n tests. This documentation pass did not rerun tests, builds, detectors or browser checks.

The translations were authored and checked by Codex, without native-speaker certification. Existing USD amounts and commercial terms remain unchanged. Search annotations and sitemap inclusion do not establish indexing or ranking.

## Incumbent comparison and preserved drift

The extension follows the incumbent violet action, lavender focus and dark tonal navigation treatment. It introduces no global visual token or system-wide prohibition. `PRODUCT.md`, `DESIGN.md` and `.impeccable/design.json` are preserved by this documentation pass.

Pre-existing documentation drift remains recorded without repair. `DESIGN.md` and its sidecar describe a 130px desktop / 56px mobile homepage display and 28px desktop supporting copy. Current English homepage CSS uses `clamp(48px, 5.2vw, 72px)` on desktop, `clamp(24px, 7.2vw, 42px)` on mobile and 22px desktop supporting copy. The translated heading override above belongs to this extension. The sidecar's action examples still show a mailto early-access destination, while current primary actions lead to pricing and the separate form offers product updates. These older system records should not be used to restore superseded homepage or availability behavior during language maintenance.
