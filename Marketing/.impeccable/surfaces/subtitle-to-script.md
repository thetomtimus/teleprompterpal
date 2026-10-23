---
version: 1
slug: "subtitle-to-script"
primary_target: "src/pages/tools/subtitle-to-script.astro"
related_targets: ["src/styles/subtitle-script.css", "src/lib/subtitle-script.ts", "src/scripts/subtitle-script.ts", "tests/subtitle-script.test.ts", "src/styles/tools.css", "src/styles/script-cleaner.css", "src/pages/tools/index.astro", "src/components/Icon.astro", "src/layouts/Layout.astro"]
---

# Teleprompter Pal subtitle to script converter

Mode: Operate. Status: **APPROVED FOR PUBLICATION**, 24 October 2026. Scope: `/tools/subtitle-to-script/` and its discovery card in `/tools/`. The owner requested the next tool in the incumbent design and a preview before publication. The independent finish reviewer returned **ship** with no material fixes. The owner reviewed the local preview and explicitly approved publication of the converter and updated tools page on 24 October 2026, including sitemap inclusion. Release verification is recorded separately after deployment.

## Direction contract

THESIS: Turn existing subtitles into an editable spoken script while preserving the caption wording.

OWN-WORLD: Reuse the calculator and cleaner’s self-hosted Figtree, near-black canvas, dark paired panels, lavender text, links and focus, violet actions, shared header/footer and native controls. The source-authority ground remains the incumbent near-black (`#0f0f0f`).

STORY: Existing SRT or VTT file or pasted captions → validation → plain-text script → copy or TXT download → cleanup, timing or rehearsal.

FIRST VIEWPORT: Shared navigation, breadcrumbs, descriptive heading, file import and paired original/result fields on desktop. Phones present the original first and then the result in document order.

FORM: The owner explicitly pinned the existing tools’ design. This is a code-led extension, with no new world or comparative composition. No QUALITY BAR card or comparative selection was made; the owner’s precise incumbent reference governs. The signature is live conversion with the original retained and complete-output validation before export.

Constraints: Convert existing subtitles only. Do not claim transcription, translation or rewriting. Text and filenames remain in page memory, with no upload, browser storage or URL transport. Preserve the released-iPhone product authority in `PRODUCT.md` and the current translated navigation, help and footer. Local preview: `http://127.0.0.1:64135/tools/subtitle-to-script/`. The owner has reviewed and approved the preview for publication.

## Implemented composition

The surface imports the existing tools and cleaner styles before its small local stylesheet. It inherits the responsive content container, breadcrumbs, quiet FAQ disclosures and next-step treatment. The heading uses the existing local Figtree tool role (56px / 1.1), becoming 38px at 767px and 34px at 374px. Introductory copy is 20px, then 18px on mobile. These are existing surface roles, not new global tokens.

The file chooser precedes the workspace, with an outlined lavender pill, accepted-format and size guidance, and a wrapping filename. The enclosure has equal desktop columns, dark tonal fills, a 24px radius and a single translucent divider. Below 767px it becomes a source-first stack with a horizontal divider and 20px enclosure radius. Pane padding steps from 28px to 24px, 22px and 18px. Textareas have 12px corners, a near-black fill, visible border, lavender focus and Figtree (17px / 1.6; 16px on mobile). Their minimum height is 268px desktop and 220px mobile. The result is readonly and remains manually selectable.

Original character count, result word count and conversion summary sit under their respective fields. Example and clear actions remain quiet underlined links. Copy uses the existing violet primary pill; TXT download uses its lavender outlined companion. Export controls retain 48px minimum height and wrap on small screens.

Script-layout radios and the optional speaker-name checkbox follow the enclosure. At 320px the layout selector becomes a vertical, full-width rounded control, allowing both labels to remain readable. This is a responsive adaptation of the pinned controls. The privacy/status area, explanation and SRT example, native FAQ, timing action and rehearsal links follow in reading order. The page introduces no artwork or display glow.

## Local state and behavior

- Initial state: source and result empty, zero counts, “Join captions” selected and speaker names off. Copy, download and clear are disabled. JavaScript enables the fieldset; without it, guidance and the example remain readable alongside the requirement notice.
- Paste or file import parses SRT and WebVTT blocks. Input accepts up to 300,000 characters. Files must have an `.srt` or `.vtt` extension and fit the byte limit (2 × 1024 × 1024 bytes; labelled “2 MB” in the interface).
- File decoding accepts UTF-8 and BOM-marked UTF-16LE/BE with fatal decoding. Unreadable encodings, unsupported extensions and oversized files produce corrective status feedback without replacing previous valid input. A revision guard prevents a stale asynchronous file read from replacing a newer source. A malformed imported caption file is shown in the source for correction.
- Cue time ranges, identifiers, common caption tags and inline timestamps are removed. WebVTT header, NOTE, STYLE and REGION blocks are excluded. Supported character entities are decoded as text. The output remains plain text; subtitle content is never interpreted as HTML.
- File order, Unicode dialogue, spoken numbers, punctuation, repeated or overlapping captions and sound descriptions are retained. There is no deduplication or script rewriting. Names already written in dialogue remain. Names provided in WebVTT voice tags are included only when “Keep speaker names” is selected.
- “Join captions” yields one paragraph; “Keep caption breaks” separates cues with blank lines. Caption-internal whitespace is joined. Settings update the live result without replacing the original. Result word counts reuse the calculator’s local counter.
- A malformed caption marks the source invalid, explains the block problem and withholds the entire script and both exports. The tool never offers an apparently complete result assembled from only the valid leading cues. Empty or formatting-only text does not enable export.
- Status is polite and announces readiness or corrective feedback after 500ms. Source errors use the existing pale-pink treatment (`#ffb0c7`) and `aria-invalid`. Native radios, checkbox and buttons retain keyboard operation and visible focus.
- Copy uses the Clipboard API. If unavailable or denied, it focuses and selects the result and explains manual copy or download. TXT download creates UTF-8 plain text named `subtitle-script.txt`, then revokes its temporary object URL.
- Example and clear refresh counts and export availability, focus the original and return its caret/scroll to the beginning. Source changes clear the imported filename. Copy and download feedback identifies the completed action.
- Subtitle text and filenames are not uploaded, persisted, added to URLs or passed automatically to related tools. Visitors explicitly copy and paste when following the cleaner, timing or separate rehearsal links. The production site’s general analytics disclosure is retained; subtitle content is excluded. The local review build has no analytics and is noindex.

## Evidence and validation

This documentation pass read the implementation, incumbent styles, `PRODUCT.md`, `DESIGN.md`, existing tool briefs and the recorded receipts. It inspected the converter preview and 320px full-page capture directly. It did not rerun implementation tests or a browser/polishing loop.

The implementation and independent-review handoff record:

- Strict Astro diagnostics over 66 files: zero errors, warnings or hints. The preview build emitted 110 routes. All 35 tests passed: nine converter, six cleaner, six calculator, seven referral/privacy and seven i18n checks. `git diff --check` passed.
- Browser checks covered empty state, paste and real SRT/VTT import, metadata removal, speaker names, both layouts, clipboard success verified by paste, exact downloaded text, malformed-cue export blocking, extension/encoding/size errors, reset and card navigation. No browser console errors or warnings were observed.
- No horizontal document overflow at 1280px, 390px or 320px. Local routes returned 200. The preview applies noindex meta/header and disables analytics. The new converter is in the generated sitemap; it is not live.
- Independent finish review returned **ship**, accepted persistence, fidelity, ceiling, TYPE/MATERIAL/GROUND and all five direction blocks, and found no material fixes. The 320px source-first and selector adaptations were accepted.
- The single design scan recorded zero nonadvisory and eight advisory findings across this extension: five local type roles, two comparison-icon radii and the incumbent error color. Those local values were retained rather than promoted to new global tokens.

Visual evidence is in `.impeccable/review/subtitle-converter/`: `empty-desktop.png` and `converter-desktop.png` (1280 × 3174), `converter-mobile.png` (390 × 4533), `converter-narrow-mobile.png` (320 × 4941), and `converter-preview.png` (desktop tool clip). The directory captures are recorded in `tools-directory.md`. Capture files contain JPEG bytes despite the `.png` suffix. The independent reviewer inspected all nine captures.

Receipts are outside the worktree at `/Users/thomas/Desktop/Projects/Teleprompter/output/subtitle-converter-preview-2026-10-24/`: `verification.json`, `sources.json`, `design-scan.json` and `static-verification.json`. Base commit: `bb4c8486ad7ded6e1f418c32723e662519af9e14`.

## Incumbent comparison and preserved drift

The extension follows the existing Violet Action, Three Voices and Local Light rules: Figtree handles the tool, lavender marks links/focus, violet marks actions/selection, and dark panels keep reading text clear. `PRODUCT.md`, `DESIGN.md`, `.impeccable/design.json`, existing surface briefs and runtime files are outside this documentation pass’s write boundary.

Existing global records and older tool briefs retain obsolete homepage type and early-access/private-beta examples. Current source styles and `PRODUCT.md`’s released-iPhone authority govern. That drift and the local scan advisories are recorded, not canonized as global tokens or repaired by an ordinary extension. The preview pass did not publish or submit indexing requests. The subsequent owner-approved release uses the existing Git/Vercel workflow. Automatic script transfer remains outside scope.
