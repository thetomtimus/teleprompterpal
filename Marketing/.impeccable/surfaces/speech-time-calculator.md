---
version: 1
slug: "speech-time-calculator"
primary_target: "src/pages/tools/speech-time-calculator.astro"
related_targets: ["src/pages/tools/index.astro", "src/styles/tools.css", "src/lib/speech-time.ts", "src/scripts/speech-calculator.ts", "src/components/SiteHeader.astro", "src/components/SiteFooter.astro", "src/styles/global.css"]
---

# Teleprompter Pal speech time calculator

Mode: Operate. Scope: the local `/tools/` directory, `/tools/speech-time-calculator/`, and their discovery links in the established marketing site. This is an ordinary code-led extension. It does not introduce a visual identity or change the native app.

## Direction contract

THESIS: Creators fit spoken words into a video or speech time limit.

OWN-WORLD: Keep the existing self-hosted Figtree, near-black canvas, lavender text and links, violet pills, approved wordmark, and shared header/footer.

STORY: Script or word count → pace and pauses → speaking duration. Offer a personal timed pace and a reverse word budget, then a separate browser rehearsal or the iPhone private-beta handoff.

FIRST VIEWPORT: Shared navigation, breadcrumb, descriptive heading, and paired input/result areas on desktop. Stack native controls in reading order on mobile.

FORM: The precisely scoped request extends a coherent incumbent world. Standard Operate controls and state-driven motion satisfy the task without a new seed or concept selection. The signature is a measured personal pace that updates both calculators.

Constraints: Scripts are never uploaded, stored or placed in URLs. The timed test needs no microphone. All timing remains approximate for spaced text. Preserve truthful private-beta availability and the shared early-access CTA. No new raster assets or publication are part of this extension.

## Implemented composition

The main input/result enclosure uses the existing 24px panel radius, dark tonal surfaces and a single translucent divider. Its desktop grid is 1.25fr/1fr, tightens to 1.1fr/1fr at 959px, and becomes one column at 767px. On mobile the panel radius becomes 20px. Local padding steps from 28px to 24px, 22px and 18px. The page inherits the incumbent responsive content container.

The tool heading is a local Figtree role (56px / 1.1), becoming 38px at 767px and 34px at 374px. It uses luminous lavender-white without the homepage display glow. The duration is tabular Figtree (64px / 1.1; 56px on mobile). Supporting text, native form controls and quiet rules make the operation readable without device imagery. These are local surface decisions, not additions to the global type scale.

Paste-script and manual-count modes use native radio inputs styled as the established rounded selected-violet controls. Number fields have dark fills, 12px corners, 48px minimum height and visible labels. Pace examples use mutually exclusive pressed states. Primary timer and early-access actions inherit the existing violet pill treatment, hover/focus behavior and reduced-motion rules. The formulas, reference table, native FAQ and handoff follow the calculator in document order.

The tools index has one plain directory item with a direct calculator link. Shared desktop navigation marks Tools as the current location. The added header accommodation hides Questions at widths 768–1100px; all links remain in the existing mobile disclosure. Footer discovery exposes both the directory and the calculator.

## Local state and behavior

- Initial state: empty script, 0 words, duration placeholder, 150 words/min, 0 extra pauses, and an independent one-minute budget of 150 words.
- Script mode counts spoken tokens locally. The input accepts at most 300,000 characters. Contractions, hyphenated words and numeric separators remain single tokens. Manual mode accepts 1–1,000,000 whole words. Switching modes retains page-memory input.
- Pace accepts 40–400 whole words/min; presets are 120, 150 and 180. Extra pauses accept 0–3,600 whole seconds. Invalid values explain the problem and withhold the affected result.
- Duration is `words / wordsPerMinute * 60 + pauseSeconds`, rounded once to the nearest second for display. Hours appear when needed.
- The target accepts 0–180 whole minutes plus 0–59 whole seconds, with positive total time. Budget is `floor(max(0, targetSeconds - pauseSeconds) / 60 * wordsPerMinute)`. If pauses consume the target, the result is zero with an explanation.
- The reading test derives its word count from the passage (currently 101). Start/finish/reset update the elapsed clock. A valid measured pace is rounded and applied to both calculators only when requested. A hidden tab cancels an active test; 40–400 remains the valid measured range.
- Script text never leaves page memory. There is no script storage, URL transport or automatic transfer to the separate browser teleprompter. The site retains its existing general analytics disclosure.
- Native controls retain keyboard operation and visible focus. Independent duration and word-budget status regions announce changed feedback after 500ms. The elapsed clock is not live-announced. Focus follows timer state and returns to the pace control when applying a measurement.
- Without JavaScript, the disabled form and timer explain their requirement while formulas, reference values and supporting content remain available.

## Evidence and validation

Implementation evidence: the five primary calculator/directory files listed above, shared header/footer, `src/styles/global.css`, `src/layouts/Layout.astro`, `tests/speech-time.test.ts` and `scripts/prepare-deployment.mjs`.

Local commands (Node 24):

```sh
node --test tests/speech-time.test.ts tests/signup-context.test.ts
npm run build
```

The first command covers calculator counting/arithmetic/formatting and the existing signup referral privacy checks. The build runs strict Astro/TypeScript diagnostics, emits the static routes and checks production canonical URLs. Both routes define their own title and description and are discovered by the existing sitemap generator.

Visual evidence inspected: `.impeccable/review/speech-calculator/desktop.png` (1440px, populated), `mobile.png` (390px, populated), `initial-empty.png` (1280px) and `tools-index.png` (1280px). The implementation review also retains `narrow-mobile.png` (320px), `default-desktop.png` (1280px, populated) and `home-tablet.png` (820px).

## Incumbent comparison and preserved drift

The extension follows the incumbent Violet Action Rule, Three Voices Rule and Local Light Rule: Figtree handles the tool, lavender marks links and focus, dark panels dominate, and reading text has no decorative glow. It introduces no new global token or marketing-system prohibition. `PRODUCT.md`, `DESIGN.md` and `.impeccable/design.json` remain unchanged.

Pre-existing drift is recorded without repair. `DESIGN.md` and the sidecar describe a 130px desktop / 56px mobile homepage display and 28px desktop supporting copy, while current homepage CSS uses `clamp(48px, 5.2vw, 72px)` / `clamp(24px, 7.2vw, 42px)` display roles and 22px desktop supporting copy. Sidecar access-action examples still contain the earlier mailto destination, while live actions use the shared early-access signup. An ordinary tool extension does not authorize rewriting those global records or restoring old homepage values.
