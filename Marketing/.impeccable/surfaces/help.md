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

Updated October 24, 2026 for the owner's approved finalization with real app screenshots and demonstrations in all seven languages. The direction contract above remains unchanged. The fresh finish reviewer returned **ship**, with no material fixes after three initial loading-state captures were replaced. This entry describes the reviewed local implementation; it does not establish production deployment.

The help shell retains the established near-black canvas, self-hosted Figtree, lavender links and focus, approved app icon, wordmark, and shared language controls. Reading density remains specific to this surface: body text is 16px with 1.65 line-height, the lead is 18px, the desktop H1 is 40px, and section headings are 25px. Hairline rules separate navigation, illustrated instruction groups, topic rows, pagination, and support; the article itself stays on the page canvas. These local choices do not replace the marketing system or its hero typography. `DESIGN.md` and `.impeccable/design.json` are preserved without regeneration or unrelated drift repair.

The desktop shell is capped at 1480px with 40px side padding. Its three-column grid uses a 210px topic sidebar, flexible reading column, and 160px section rail with 42px gaps. Both rails stay in view while scrolling and can scroll within the viewport. The header combines the wordmark, a labeled 44px search field, website link, and language chooser. Breadcrumbs and a practical lead introduce each article; previous/next links and a support destination close it. The overview retains its four-part script-to-export sequence and script-library capture, then groups the eight articles by task.

Media now accompanies the relevant instruction section instead of placing one image beside an entire article. Each illustrated section pairs flexible instructions with a 230px media column and a 28px gap. A following section receives a quiet separating rule and 34px top padding. The fourteen new native WebP captures cover the editor, script actions, text import menu and file picker, rehearsal and its controls, camera and recording state, trimming, crop controls and preview, export readiness, destinations, and successful Photos delivery. Four silent MP4 demonstrations show rehearsal, recording controls, trimming, and cropping. The old colored test-clip trim and export images are replaced by captures containing real sample footage.

Responsive changes preserve reading order:

- At 1250px and below, the section rail becomes an inline native disclosure. The topic sidebar remains beside the article.
- At 800px and below, search occupies its own full-width header row, the topic list becomes a disclosure above the article, and the website link leaves the header. With JavaScript enabled, the topic list starts closed; the source markup keeps it open when JavaScript is unavailable. Illustrated sections use a 210px media column and 24px gap at this intermediate width.
- At 560px and below, each screenshot or demonstration follows its own instruction group and is centered at a maximum width of 290px. Topic groups stack and the H1 is 32px. The overview capture remains capped at 220px. Following illustrated sections use 28px top padding.

Screenshots and videos retain their original proportions. Screenshot framing has 24px corners; video framing has 20px corners, a dark background, and the same quiet border. Captions use 12px type with 1.6 line-height. Screenshot links open the full-size image; video captions include a translated link to the full-size MP4. These links and native video controls have a visible lavender focus outline.

The new captures show the actual Teleprompter Pal 0.6.12 build 32 interface running on an iPhone 17 simulator with iOS 27. English UI pixels are preserved, with translated instructions and captions in every locale. The recording article explicitly explains that the simulator camera preview is blank and the take is simulated. The trimming and cropping fixture contains CC0 bee footage loaded into isolated test data; it was not filmed using the app. Provenance is maintained in [the asset manifest](../../docs/asset-provenance.json) and [maintenance notes](../../docs/help-center.md). These captures demonstrate native controls, not physical-device camera quality.

## Finished behavior

The overview and eight articles are rendered in English, Spanish, German, French, Brazilian Portuguese, Japanese, and Korean: 63 help pages. Both language controls retain the current topic. The article list supplies routes, grouped navigation, search entries, and previous/next destinations; every page has section anchors and a current-page navigation state. Articles and navigation remain usable without JavaScript.

Each silent MP4 uses native browser controls, inline playback, a matching screenshot poster, and `preload="none"`. It starts only when the visitor chooses to play it. There is no autoplay or custom player dependency. Captions explain the action and provide a direct video link, while the adjacent written steps carry the instructions without requiring motion or audio. A translated note explains that screenshots and demonstrations show English app controls. Image alternative text and video accessible labels use the translated descriptive captions.

The import article now separates opening Import Text from choosing and checking the file. Rehearsal instructions match the actual Play text, Pause text, Pace, and Font controls. Export separates MP4 preparation from choosing a destination, then explains how to confirm the video was saved. The destination capture shows Photos, Files, and Share; the final capture shows successful Photos delivery. Native capture tests also exercised saving to Files and opening the share sheet.

Search filters the current language's rendered titles, descriptions, section headings, and instructions locally. Normalization removes combining marks, folds case, and normalizes whitespace; all query terms must match, including Japanese and Korean text. A nonempty query opens results, an empty query hides them, and a status message reports no matches. Arrow Down from the field focuses the first matching link. Escape dismisses results and returns focus to the input; clicking outside also dismisses them. Search creates no result URLs and sends no queries to a service. Shared focus and reduced-motion styles remain in effect.

Locale output has page-specific canonicals, reciprocal language alternatives, sitemap entries, and localized metadata. Adding or changing English content requires corresponding strings in all six translation catalogs, including captions, media labels, and the new instruction sections. The guide-sync source set includes the new shared media component. Native app changes still require a content and capture review; translation completeness alone cannot prove the guide matches a later app release.

## Recorded verification and limits

The fresh finish review inspected fourteen valid desktop and mobile captures: English trim/crop, Spanish import, German script creation, French rehearsal, Brazilian Portuguese export, Japanese recording, and Korean export at 1440px and 390px. The reviewer returned ship without material fixes after replacement of three incomplete loading-state captures. This set includes dedicated visual coverage for all seven languages, while sampling different tasks rather than visually inspecting every route/locale combination.

Current evidence in `.impeccable/review/help-final/` includes:

- [build.log](../review/help-final/build.log): zero Astro errors, warnings, or hints; 379 checked strings across seven locales. Deployment preparation reports `published: false` and `deployed: false`.
- [browser-results.json](../review/help-final/browser-results.json): twelve non-English desktop/mobile page measurements show no horizontal overflow. The media-bearing entries confirm translated video labels, matching posters, and `preload="none"`.
- Desktop and mobile page captures named `desktop.png`, `mobile.png`, and the `es`, `de`, `fr`, `pt-br`, `ja`, and `ko` prefixed equivalents. These are the fourteen captures used by the reviewer.
- The native capture run at the repository root, `.impeccable/review/help-final/capture.log`, records three passing tests with zero failures: import/rehearsal, recording controls, and trim/crop/delivery. Its retained XCTest attachments provide the source screenshots.

The implementation handoff reports ten passing help and localization tests. The added media test checks every illustrated section in every locale for a shipped asset, translated description, accessible full-size fallback, and user-controlled video attributes. Earlier shell behavior checks remain recorded in `.impeccable/review/help/`; they are historical evidence, not fresh tests of every updated page.

This documentation pass checked `PRODUCT.md`, `DESIGN.md`, the existing surface contract, `src/styles/help.css`, `HelpLayout.astro`, `HelpMedia.astro`, the article template, `help.mjs`, the media test source, and the saved build/browser/native-capture records. It reran no build, browser check, test, or detector. Final encoded-video playback and deployment verification remain the implementation owner's finish steps. The ship disposition is not an independent native-speaker audit, physical-iPhone recording test, production deployment confirmation, indexing result, or certification of unrelated pages. No separate approved comp applies to this ordinary extension.
