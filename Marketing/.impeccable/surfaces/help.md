---
version: 1
slug: "help"
primary_target: "src/layouts/HelpLayout.astro"
related_targets: ["src/pages/help/index.astro", "src/pages/help/[slug].astro", "src/styles/help.css", "src/data/help.mjs"]
---

# Teleprompter Pal user guide

Mode: Read. Ordinary code-led extension of the incumbent site, approved by the owner on October 23, 2026. Reference: guide.teleprompterpro.com/teleprompter/duo-script/, for documentation structure only. The owner explicitly asked for `/help/`, real screenshots from Teleprompter Pal and all seven website languages.

THESIS: Help a person complete a specific task in the app, with navigation that keeps their place and real controls they can recognize.

OWN-WORLD: Preserve near-black, self-hosted Figtree, lavender links/focus, wordmark and seven-language chooser. Documentation uses compact typography and quiet rules instead of the marketing hero.

FIRST VIEWPORT: Wordmark, searchable guide and language selector across the top. On desktop, topic sidebar left, title and practical instructions center, section links right. The overview begins with a sequential path from script through export and an actual script-library capture. Article screenshots sit beside instructions when space allows. Mobile has collapsible topic/section navigation and a full-width search field.

FORM: Eight task articles plus an overview, every page in all seven languages. In-place search matches the current language's rendered article text, including accents and CJK, with keyboard focus, no-result feedback, and no query tracking. Same-topic switching works at top and bottom. Original app screenshot text stays English and control names match it.

QUALITY BAR: The requested documentation hierarchy is immediately clear, screenshots remain legible and undistorted, every article has actionable steps, long translations fit narrow screens, and all controls have working destinations. Use test-clip screenshots honestly; no illustrated camera feed presented as a real recording.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance. Preserve existing DESIGN.md and sidecar because this is an ordinary extension; document finished evidence here.

## Finished composition

Documented October 24, 2026 after the work begun October 23. The direction contract above remains unchanged. The local implementation has a **ship** disposition in [the finish review](../review/help/finish-review.md), with no material fixes identified. This is a reviewed local build, not a live deployment.

The help shell retains the established near-black canvas, self-hosted Figtree, lavender links and focus, approved app icon, wordmark, and shared language controls. Reading density is specific to this surface: body text is 16px with 1.65 line-height, the lead is 18px, the desktop H1 is 40px, and section headings are 25px. Hairline rules separate navigation, topic rows, pagination, and support; the article itself stays on the page canvas. These local choices do not replace the marketing system or its hero typography. `DESIGN.md` and `.impeccable/design.json` are preserved without regeneration or unrelated drift repair.

The desktop shell is capped at 1480px with 40px side padding. Its three-column grid uses a 210px topic sidebar, flexible reading column, and 160px section rail with 42px gaps. Both rails stay in view while scrolling and can scroll within the viewport. The header combines the wordmark, a labeled 44px search field, website link, and language chooser. Breadcrumbs and a practical lead introduce each article; previous/next links and a support destination close it. The overview pairs a four-part script-to-export sequence with the script-library capture, then groups the eight articles by task.

Responsive changes preserve that reading order:

- At 1250px and below, the section rail becomes an inline native disclosure. The topic sidebar remains beside the article.
- At 800px and below, search occupies its own full-width header row, the topic list becomes a disclosure above the article, and the website link leaves the header. With JavaScript enabled, the topic list starts closed on these screens; the source markup keeps it open when JavaScript is unavailable.
- At 560px and below, screenshots follow the first instruction group, topic groups stack, and the H1 is 32px. Article screenshots are capped at 260px and the overview capture at 220px, with links to their full-size originals.

Screenshots remain proportional, with quiet descriptive captions and lightly rounded framing. Existing script-library, editor, and Reader Settings assets are reused. The added trim and export images are unmodified October 16 iPhone Simulator captures; their captions identify the sample test clip. English screen labels remain intact and are explained in translated copy. Provenance is recorded in [the asset manifest](../../docs/asset-provenance.json) and [maintenance notes](../../docs/help-center.md). No generated interface or camera feed was added, and these images do not establish fresh physical-device or recording-quality evidence.

## Finished behavior

The overview and eight articles are rendered in English, Spanish, German, French, Brazilian Portuguese, Japanese, and Korean: 63 help pages. Both language controls retain the current topic. The article list supplies routes, grouped navigation, search entries, and previous/next destinations; every page has section anchors and a current-page navigation state. Articles and navigation remain usable without JavaScript.

Search filters the current language's rendered titles, descriptions, section headings, and instructions locally. Normalization removes combining marks, folds case, and normalizes whitespace; all query terms must match, including Japanese and Korean text. A nonempty query opens results, an empty query hides them, and a status message reports no matches. Arrow Down from the field focuses the first matching link. Escape dismisses results and returns focus to the input; clicking outside also dismisses them. Search creates no result URLs and sends no queries to a service. Shared focus and reduced-motion styles remain in effect.

Locale output has page-specific canonicals, reciprocal language alternatives, sitemap entries, and localized metadata. Adding or changing an English article requires corresponding strings in all six translation catalogs. Native app changes still need a content review; website translation checks cannot prove the guide matches a later app release.

## Recorded verification and limits

The finish reviewer inspected all 12 supplied captures: the English overview, German script creation, Japanese recording, Korean export, and English trim/crop at 1440px and 390px, plus the 320px language-menu and 844 × 390 landscape-menu states. The review found the captures valid and the composition consistent with the Read brief.

Saved evidence in `.impeccable/review/help/` records:

- [build.log](../review/help/build.log): zero errors, warnings, or hints; prepared output explicitly reports `published: false` and `deployed: false`.
- [tests.log](../review/help/tests.log): all nine tests pass, including localized article navigation, search normalization, translation guards, and language alternatives.
- [browser-results.json](../review/help/browser-results.json): the ten page captures have no horizontal overflow or broken images; search in all seven locales, keyboard entry, empty results, Escape, same-topic switching, mobile browse, section links, and short-screen language navigation pass; no page errors are recorded.
- [header-regression.json](../review/help/header-regression.json): the supplementary check of all seven existing homepage headers records no overflow, overlap, or controls outside the viewport, with a localized help destination in each. The implementation handoff identifies the checked width as 1280px and confirms no implementation changes after the ship verdict.
- [links.json](../review/help/links.json): 109 generated HTML pages and 5,812 local references checked with no errors. This count covers the generated site, not only the help pages.

This documentation pass used the saved source, review, and verification records; it reran no build, browser check, test, or detector. Spanish, French, and Brazilian Portuguese have translation/search evidence but no dedicated visual capture in this set. Search-result styling and every route/locale combination were not independently visually reviewed. The ship verdict is not an independent linguistic audit, deployment confirmation, indexing result, or certification of unrelated pages. No separate approved comp applies to this ordinary extension.
