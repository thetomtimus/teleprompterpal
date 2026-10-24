---
version: 1
slug: "tools-directory"
primary_target: "src/pages/tools/index.astro"
related_targets: ["src/styles/tool-cards.css", "src/styles/compare.css", "src/styles/tools.css", "src/components/Icon.astro", "src/components/SiteHeader.astro", "src/components/SiteFooter.astro"]
---

# Teleprompter Pal tools directory

Mode: Operate. Current baseline: **PUBLISHED (three tools)**. Fourth-card extension: **APPROVED FOR PUBLICATION**, 24 October 2026. The original card directory and subtitle-to-script converter received explicit owner publication approval on 24 October; the calculator, cleaner and converter remain published. The current local extension adds the speech rehearsal timer in the same design, with preview requested before publication. Independent finish review returned **SHIP** with no material fixes for the local preview only. The owner has reviewed the preview and approved the timer and fourth-card release, with sitemap inclusion and no sitemap submission or indexing notification. The direction and composition below preserve the original three-card release record; current inventory and extension evidence are recorded separately below.

## Direction contract

THESIS: Help visitors choose a useful preparation tool before recording a talking video.

OWN-WORLD: Retain the calculator/cleaner’s self-hosted Figtree, near-black canvas, lavender accents, shared header/footer and tools introduction. Directly reuse the comparison directory’s card grid and linked-card treatment.

STORY: Introductory preparation promise → compare three distinct tool jobs → open timing, cleanup or conversion → rehearse when ready.

FIRST VIEWPORT: Shared navigation and breadcrumb, the existing preparation heading and three equal cards on desktop. Phones show one column in the same timing, cleanup, conversion order.

FORM: The owner pinned the comparison cards as the visual reference. This is direct code-led reuse of the incumbent world, with no rebrand, concept tournament or QUALITY BAR card/comp selection. Each card is a single complete link with a recognizable tool icon, task description and action cue.

Constraints: Keep current product truth, navigation, translated help and footer intact. Tools remain free, with no signup and local script handling. Preserve the released-iPhone positioning from `PRODUCT.md`. Local preview: `http://127.0.0.1:64135/tools/`. The owner has reviewed and approved the preview for publication.

## Implemented composition

The tools page imports the existing tools stylesheet, comparison stylesheet and a small tool-card adaptation. It directly uses `compare-card-grid` and `compare-app-card`; there is no second imitation of the card system. The incumbent tools heading, “A little prep. A better take.”, remains above the grid with the short preparation description.

The grid uses 24px gaps and automatic equal columns, each with a minimum of 320px when space permits. At 1280px all three cards fit in one row; at 390px and 320px they form a single column. Cards have dark surfaces, one translucent border, 24px corners and 28px padding, with an icon column (56px), a 20px gap and a flexible copy column. At 767px padding becomes 24px, the gap 16px and corners 20px. At 374px padding becomes 20px, icon column 44px and gap 12px. These are local adaptations, not global token additions.

Each card contains an installed Phosphor SVG icon (timer, broom or subtitles), an H2, quiet category, short practical summary and lavender text/arrow action. The icon sits in a raised dark tile with lavender art, reusing the comparison icon’s 13px radius; the tile becomes 44px with 12px corners on the narrowest screen. No new raster art was introduced.

Card headings inherit the comparison role (22px / 1.25, then 21px below 767px). Categories are 14px / 1.5, summaries 18px / 1.5 (16px at 374px), and action cues 15px / 1.5. Flexible summary space aligns the action cues across equal-height desktop cards. The entire card is one anchor, so the visible action does not create a nested control. Hover shifts its border to lavender and raises the tonal background; keyboard focus uses the shared lavender outline. Motion remains brief and respects the global reduced-motion preference.

Below the cards, the quiet lock/privacy line says the tools are free with no signup and that scripts stay in the browser. The existing rehearsal note links to the separate browser teleprompter and the browser-versus-iPhone guide. Shared navigation marks Tools as current. No scripts are automatically passed through any link.

## Tool inventory

- **Speech time calculator — PUBLISHED** → `/tools/speech-time-calculator/`: estimate duration, measure pace and find a word budget. Category: “Timing and rehearsal.” Action: “Time your script.”
- **Script cleaner — PUBLISHED** → `/tools/script-cleaner/`: remove unwanted line breaks and spaces or form reading chunks. Category: “Script preparation.” Action: “Clean your script.”
- **Subtitle to script — PUBLISHED** → `/tools/subtitle-to-script/`: remove caption timecodes, then copy or download plain text. Category: “SRT and VTT to text.” Action: “Convert your subtitles.”
- **Speech rehearsal timer — APPROVED FOR PUBLICATION** → `/tools/speech-rehearsal-timer/`: time actual delivery, show a wrap-up warning, exclude pauses and track overtime. Category: “Live delivery practice.” Action: “Start a rehearsal.” It reuses the installed play icon and existing linked-card treatment.

The directory is static and works without a page-specific script. The tools themselves retain their separately documented local behavior and JavaScript requirements.

## Evidence and validation

Current local extension (24 October 2026): the fourth card reuses the unchanged comparison grid and tool-card styles. Reviewed desktop shows a three-plus-one arrangement, accepted by the independent reviewer; 390px and 320px remain one column. The first three entries retain their published destinations. Current preview: `http://127.0.0.1:64136/tools/`.

The rehearsal-timer handoff records 72 Astro files with zero errors/warnings/hints, all 43 tests passing (six timer tests), 113 routes, a passing `git diff --check`, resolving card navigation/assets/canonicals, no horizontal overflow and no console errors or warnings. Both local routes return 200; the preview is noindex with analytics disabled. The timer occurs once in the generated sitemap and is unpublished. Automatic page/CSS design hooks found zero deterministic findings. Independent finish review inspected all 15 captures and returned **SHIP** with persistence, fidelity and ceiling passing and no material fixes, covering the local preview only.

Current directory evidence in `.impeccable/review/rehearsal-timer/`: `tools-desktop.png` (1280 × 2017), `tools-mobile.png` (390 × 2724) and `tools-narrow-mobile.png` (320 × 2766). Files contain JPEG bytes despite the suffix. Receipts are in `/Users/thomas/Desktop/Projects/Teleprompter/output/rehearsal-timer-preview-2026-10-24/`: `verification.json`, `sources.json`, `static-verification.json`, `build.log`, `prepare.log` and `tests.log`. Base: `fb97db5632be0a9a8705fbb56cbc0b4a09b30ae5`. Timer behavior and the remaining captures are recorded in `speech-rehearsal-timer.md`. This documentation update read source and receipts without rerunning UI, tests or polish.

The following paragraphs preserve the original converter/card preview evidence. That documentation pass read the page, comparison/tool-card styles, shared tokens, icon component, existing tool briefs, `PRODUCT.md`, `DESIGN.md` and the completion receipts. It inspected the desktop tools preview and 320px directory capture directly. It did not rerun tests or browser checks.

The completed handoff records a successful 110-route preview build, strict Astro diagnostics over 66 files with zero errors/warnings/hints, all 35 tests passing, and `git diff --check` passing. Browser review verified all card destinations and the converter workflow, with no console errors or warnings. Both local routes returned 200, and no horizontal overflow occurred at 1280px, 390px or 320px.

Independent finish review returned **ship**, found no material fixes, accepted the pinned comparison-card reuse and narrow-screen adaptation, and passed persistence, fidelity, ceiling, TYPE/MATERIAL/GROUND and the direction contract. The one design scan found zero nonadvisory issues. Across the two surfaces, its eight advisories are existing local type values (five), comparison icon-tile radii (two) and the incumbent error color (one). Their use does not establish new global tokens.

Visual evidence in `.impeccable/review/subtitle-converter/`: `tools-desktop.png` (1280 × 1712), `tools-mobile.png` (390 × 2401), `tools-narrow-mobile.png` (320 × 2440) and `tools-preview.png` (desktop directory clip). The capture files contain JPEG bytes despite the `.png` suffix. The independent reviewer inspected all nine directory/converter captures; converter evidence is detailed in `subtitle-to-script.md`.

Receipts are outside the worktree at `/Users/thomas/Desktop/Projects/Teleprompter/output/subtitle-converter-preview-2026-10-24/`: `verification.json`, `sources.json`, `design-scan.json` and `static-verification.json`. Base commit: `bb4c8486ad7ded6e1f418c32723e662519af9e14`. That local review build had noindex meta/header and analytics disabled; the converter appeared in its sitemap before the subsequent published release.

## Incumbent comparison and preserved drift

The tools grid now follows the owner-pinned comparison cards rather than the older plain directory rows described in the calculator and cleaner briefs. Those briefs were preserved as historical surface records. This directory brief records the current extension.

Violet Action, Three Voices and Local Light remain intact: dark surfaces, Figtree copy, lavender focus/links and restrained state changes. No global product, type, palette, component or identity rule is changed. Older global type/early-access examples, the historic row descriptions and the scan advisories are recorded without repair or canonization. `PRODUCT.md`, `DESIGN.md`, `.impeccable/design.json`, existing briefs and runtime/source files were left untouched by this documentation pass.
