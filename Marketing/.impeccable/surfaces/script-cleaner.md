---
version: 1
slug: "script-cleaner"
primary_target: "src/pages/tools/script-cleaner.astro"
related_targets: ["src/styles/script-cleaner.css", "src/lib/script-cleaner.ts", "src/scripts/script-cleaner.ts", "tests/script-cleaner.test.ts", "src/pages/tools/index.astro", "src/pages/tools/speech-time-calculator.astro", "src/styles/tools.css", "src/components/SiteHeader.astro", "src/components/SiteFooter.astro", "src/styles/global.css"]
---

# Teleprompter Pal script cleaner

Mode: Operate. Scope: local `/tools/script-cleaner/`, its tools-directory entry and the calculator’s contextual incoming link. The owner requested this tool first, using the existing calculator’s design, with a preview before publication. This is an ordinary code-led extension of the incumbent marketing system. The finish reviewer returned **ship** with no material findings; that verdict describes local readiness, not publication approval.

## Direction contract

THESIS: Turn messy pasted text into a readable script while preserving the author’s words.

OWN-WORLD: Reuse the calculator’s self-hosted Figtree, near-black canvas, lavender display type, links and focus, violet pills, 24px enclosure, and shared header/footer.

STORY: Original pasted script → chosen whitespace and paragraph handling → live cleaned output → copy or download → timing or rehearsal.

FIRST VIEWPORT: Shared navigation, breadcrumbs, a descriptive heading and paired original/result textareas on desktop. Mobile stacks the original before the result in source order.

FORM: The user explicitly pinned a precise extension to the calculator. No new world, concept tournament or comparative composition applies. The signature interaction changes cleanup settings while leaving the original text untouched.

Constraints: Change whitespace and paragraph breaks only. Scripts stay in page memory, with no upload, browser storage or URL transport. Preserve the current product truth in `PRODUCT.md`: Teleprompter Pal is released for iPhone. The local preview is `http://127.0.0.1:61173/tools/script-cleaner/`; publication requires the owner’s subsequent approval.

## Implemented composition

The tool inherits the calculator’s content container, breadcrumbs, heading, dark enclosure, native controls, FAQ disclosures and next-step treatment. Its local heading is Figtree (56px / 1.1), becoming 38px at 767px and 34px at 374px. Supporting introduction copy is 20px, then 18px on mobile. These local roles extend the calculator and do not add global type tokens.

The workspace has equal desktop columns, a 24px radius and a single translucent divider. The original occupies the left pane; the readonly result occupies the darker right pane. Below 767px, they stack with a horizontal divider and a 20px enclosure radius. Pane padding steps from 28px to 24px, 22px and 18px. Textareas have 12px corners, a near-black fill, a visible border, Figtree (17px / 1.6; 16px on mobile), and minimum heights of 268px desktop or 220px mobile. Lavender focus remains visible.

Word counts, the original’s character limit and the result’s paragraph count sit below the fields. The example and clear actions are quiet underlined links. Copy uses the existing violet primary pill; download uses its lavender outlined companion. Both export actions retain 48px minimum height and wrap on narrow screens. Cleanup settings follow the enclosure: native paragraph-mode radios use the established selected-violet pills, while native checkboxes control spacing and reading chunks. The example, explanation, native FAQ and timing/rehearsal links follow in document order.

The tools directory adds one cleaner entry. Its adjacent-item rule prevents a doubled divider. The speech time calculator gains one contextual cleanup link. Shared navigation and footer are retained.

## Local state and behavior

- Initial state: empty original and result; zero counts; “Keep paragraphs” and “Clean extra spaces” selected; reading chunks off. Copy, download and clear are disabled while empty.
- Cleanup updates on input or settings changes. The source textarea accepts up to 300,000 characters and shows the count and limit guidance. Settings never replace the original.
- Line endings are normalized, and line-edge whitespace is trimmed. “Keep paragraphs” preserves blank-line separation while joining wrapped lines inside each paragraph. “Join all lines” produces one paragraph before optional chunking.
- Space cleanup collapses repeated spaces, tabs and supported nonbreaking spaces. It can be disabled. Reading chunks also normalize spaces and add paragraph breaks at a maximum of 32 whitespace-separated words, preserving sentence boundaries when possible. Long sentences can continue across chunks. Wording, spelling, punctuation and hyphens remain intact; there is no rewriting, OCR, PDF upload or dehyphenation.
- Counts reuse the calculator’s local word counter; the chunk limit uses whitespace-separated words. The readonly result can be selected manually. A polite status announces readiness after 500ms; feedback also confirms copy/download actions.
- Copy writes the current result through the Clipboard API. If denied or unavailable, the result receives focus and selection, with instructions to use the device’s Copy command or download. Download creates `cleaned-script.txt` as UTF-8 plain text, then revokes the temporary object URL.
- “Try an example” fills the source, updates the result, focuses the original, and resets its caret and scroll position to zero. Clear empties the source, refreshes disabled actions and counts, and returns focus to the original.
- No automatic script transfer occurs when following timing or rehearsal links. Visitors copy and paste explicitly. Without JavaScript, the disabled form explains its requirement; guidance and examples remain readable. The existing general analytics disclosure remains accurate; script text is not sent with analytics.

## Evidence and validation

Source evidence: the primary and related files above, plus `src/layouts/Layout.astro` and `scripts/prepare-deployment.mjs`. This documentation pass checked the implementation and existing captures; it did not rerun a browser, test or polishing loop.

The completed implementation/reviewer handoff records:

- Strict Astro diagnostics over 56 files: zero errors, warnings or hints. All 19 tests passed: six cleaner, six calculator and seven referral/privacy tests. The maximum-size fixture is exactly 300,000 characters.
- Astro build and deployment preparation completed locally with `VERCEL_ENV=preview`. The local production-style server applies CSP and noindex meta/header, with no analytics beacon observed.
- Browser checks covered real copy followed by Meta+V paste, exact downloaded-file contents, all cleanup settings, example/reset and empty states, with no browser errors. A 100-word fixture yielded 32/32/32/4 reading chunks.
- No document overflow at 1440px, 390px or 320px. Export actions measured 48px. Local links/assets returned 200; the directory/calculator discovery links and generated sitemap include the cleaner.
- The detector ran once. Its local type advisories match the incumbent calculator scale. The finish reviewer found no material fixes and accepted all five captures.

Visual evidence in `.impeccable/review/script-cleaner/`: `desktop.png` (1440px, populated), `mobile.png` (390px, populated), `narrow-mobile.png` (320px, populated), `preview.png` (1280px, top 1160px clip showing navigation and the whole tool), and `empty-desktop.png` (1280px, empty). This documentation pass inspected the preview and populated mobile captures directly; all five were validated by the finish reviewer.

## Incumbent comparison and preserved drift

The cleaner follows the Violet Action Rule, Three Voices Rule and Local Light Rule: Figtree handles the tool, lavender marks links/focus, violet marks actions/selection, dark panels dominate, and reading text carries no decorative glow. It introduces no new global token, identity, imagery or system-wide prohibition. `PRODUCT.md`, `DESIGN.md`, `.impeccable/design.json`, the calculator brief and runtime/source files were preserved during this documentation pass.

Pre-existing documentation drift is not canonized or repaired. Global records still describe older homepage display/supporting-copy sizes and early-access or private-beta examples; the calculator brief also retains earlier availability language. Current homepage CSS and the released-iPhone authority in `PRODUCT.md` govern the live implementation. This ordinary tool extension does not authorize rewriting those global records or restoring their older values.
