---
version: 1
slug: "speech-rehearsal-timer"
primary_target: "src/pages/tools/speech-rehearsal-timer.astro"
related_targets: ["src/styles/rehearsal-timer.css", "src/lib/rehearsal-timer.ts", "src/scripts/rehearsal-timer.ts", "tests/rehearsal-timer.test.ts", "src/styles/tools.css", "src/pages/tools/index.astro", "src/styles/tool-cards.css", "src/styles/compare.css"]
---

# Teleprompter Pal speech rehearsal timer

Mode: Operate. Status: **APPROVED FOR PUBLICATION**, 24 October 2026. Scope: `/tools/speech-rehearsal-timer/` and its fourth discovery card in `/tools/`. The owner requested the next tool in the existing design and a preview before publication. Independent finish review returned **SHIP**, with persistence, fidelity and ceiling passing and no material fixes. The owner reviewed the preview and explicitly approved publication of the timer and its tools-page link on 24 October 2026, including sitemap inclusion. The owner explicitly requested no sitemap submission; no indexing notifications are part of this release. Production verification is recorded separately after deployment.

## Direction contract

THESIS: Help creators time their actual spoken delivery against a target.

OWN-WORLD: Retain self-hosted Figtree, the near-black canvas, dark paired tool panels, lavender links/focus, violet actions, native fields and the shared shell. Green, amber and pink express local timing states with written cues.

STORY: Set a target and warning → start speaking → pause/resume with breaks excluded → finish under or over target → reset or start again → prepare or rehearse another take.

FIRST VIEWPORT: Setup on the left and the large clock on the right at desktop widths. Phones stack setup before the clock. Fullscreen or browser focus view isolates the clock and transport while keeping an exit visible.

FORM: The owner pinned the existing tools and cards. This is a narrow code-led extension, with no new visual world, concept tournament, comparative comp or QUALITY BAR selection. Its signature is timestamp arithmetic that recovers delayed callbacks and hidden-page time, excludes pauses and continues counting overtime.

Constraints: Preserve released-iPhone product truth, translated navigation/help and the footer. No audio, microphone, camera, timer network requests, browser storage or URL transport. Preview: `http://127.0.0.1:64136/tools/speech-rehearsal-timer/`; directory: `http://127.0.0.1:64136/tools/`.

## Implemented composition

The page imports the incumbent tools stylesheet and a small timer stylesheet. Its “Make time for a rehearsal.” heading uses the existing tool role (56px / 1.1, then 38px at 767px and 34px at 374px). Introductory copy is 20px, then 18px on phones. The shared shell, breadcrumbs, native FAQ disclosures and next-step treatment remain intact.

The dark enclosure keeps the existing 24px corners, translucent divider and panel padding (28px, then 24px, 22px and 18px). The timer changes the desktop column balance to 0.75fr / 1.25fr, then 0.8fr / 1.2fr at 959px. At 767px it becomes one column with setup first, a horizontal divider and 20px corners. Number fields and presets reuse the tool controls; all main actions retain at least 48px height.

The clock uses Figtree at weight 600 with tabular numerals, tight tracking and a local responsive size (`clamp(56px, 7.5vw, 96px)` on desktop; 72px on phones and 64px below 374px). Longer hour readings have a smaller variant. A written cue, clock label and elapsed/target/warning facts keep the meaning explicit. Local green (`#91d5a9`), amber (`#f3d58c`) and pink (`#ffb0c7`) change the cue and clock together; a dot and explanatory legend reinforce the words. These state values are not global palette additions.

The primary transport uses the existing violet pill. Finish uses its lavender outlined companion; Reset and fullscreen remain quiet underlined actions. Guidance, timing-state explanations, related preparation tools and the separate online teleprompter follow the workspace. No new imagery or display glow is introduced.

Fullscreen/focus view uses the existing dark panel ground (`#17161d`), removes enclosure corners and fills the viewport with safe-area padding. The clock enlarges to `clamp(64px, 19vw, 220px)`, with smaller long-reading and short-landscape variants. Phone and low-height layouts can scroll to retain every control and the visible exit.

The fourth directory card reuses the existing comparison grid, linked-card treatment and installed play icon. The grid shows three cards plus one on a second row at the reviewed desktop width, and one column on phones. The reviewer accepted this extension of the pinned card system.

## Local state and behavior

- Default target: 5 minutes, with a 60-second warning. Presets are 1, 3, 5 and 10 minutes; their warnings are 15, 30, 60 and 60 seconds. Custom targets accept whole values from 1 second to 3 hours. Warning accepts 0 for off, otherwise a whole value below the target. Invalid settings show corrective feedback, mark fields and disable Start.
- Start changes to Pause, then Resume when paused. Finish freezes the result and states elapsed time plus the amount under or over target. Start again begins another attempt with the same settings. Reset clears the attempt and unlocks settings. Settings stay locked from the first start until reset.
- The clock counts down, shows “Wrap up” at the warning threshold, then “Time is up” while counting upward from zero. Overtime continues until pause, finish or reset. A disabled early warning does not disable overtime.
- Timing uses accumulated active milliseconds plus `Date.now()` differences, rather than counting callbacks. Delayed updates and a hidden page catch up; paused intervals are excluded. Returning to the visible page refreshes the reading. Changing the device clock can affect measurement, as disclosed in the FAQ.
- Space operates transport when the timer region itself is focused. Status announcements follow phase or signal changes, rather than every clock tick. Controls start disabled in markup and are enabled by the script placed inside the layout body; guidance remains readable without JavaScript.
- Fullscreen is requested only after the visitor activates its control. Unsupported or rejected requests retain the fixed browser focus view. Outside content becomes inert, keyboard focus stays within the timer, and the exit button or Escape restores the page and focus. The timer continues through view changes. A phone may still dim or lock according to device settings.
- Attempts and settings live only in this tab and clear on closing or reloading. No recording, alarm, upload, persistence or automatic transfer to another tool occurs. General production analytics do not receive timer settings or results; the local preview disables analytics and applies noindex.

## Evidence and validation

This documentation pass read the timer page, styles, library, script and six timer tests, the updated directory, incumbent tool styles, `PRODUCT.md`, `DESIGN.md` and the recorded receipts. It did not rerun tests, browser checks or a polishing loop.

The completed implementation and independent-review handoff record 72 Astro files with zero errors, warnings or hints; all 43 tests passing (six timer tests); 113 built routes; and a passing `git diff --check`. Static verification records both local routes returning 200, resolving assets and correct production canonicals, noindex in preview, and exactly one timer sitemap entry.

Browser evidence covers presets, invalid settings/recovery, warning off, reset, keyboard transport, under-target finish, frozen paused time, resumed overtime and actual directory-card navigation. An 8-second target reached the warning at 6 seconds remaining, paused at 0:02, and finished at 0:19 with 0:11 over. A background interval of 5.315 wall seconds produced 0:05 elapsed. Native fullscreen and Escape worked; a separate fixture with `Permissions-Policy: fullscreen=()` verified browser focus fallback, keyboard containment, exit and focus restoration. Reviewed normal/focus sizes had no horizontal overflow; console errors and warnings were empty.

The independent reviewer inspected all 15 captures and returned **SHIP** with no material fixes. Automatic design hooks on the page and stylesheet found zero deterministic findings; a manual scan was not rerun. Evidence in `.impeccable/review/rehearsal-timer/` includes normal pages at 1280, 1512, 390 and 320px; directory captures at 1280, 390 and 320px; warning/paused, finished/overtime and invalid states; native fullscreen (1512 × 949); focus views (390 × 844, 320 × 740 and 844 × 390 landscape); and `preview.png`. The files contain JPEG bytes despite their `.png` names.

Receipts: `/Users/thomas/Desktop/Projects/Teleprompter/output/rehearsal-timer-preview-2026-10-24/` contains `verification.json`, `sources.json`, `static-verification.json`, `build.log`, `prepare.log` and `tests.log`. Base commit: `fb97db5632be0a9a8705fbb56cbc0b4a09b30ae5`.

## Incumbent comparison and preserved drift

Violet Action, Three Voices and Local Light remain intact: Figtree copy, lavender focus/links, violet actions and clear dark panels. Timer states and the clock scale remain surface-specific. No global product, identity or component rule changed.

Existing global documents retain older home type and early-access/private-beta examples. Older calculator/cleaner briefs retain the former directory rows, and the earlier converter brief retains its original preview-stage status. Current source and `PRODUCT.md`’s released-iPhone authority govern. These historical records and existing drift were neither repaired nor canonized. This pass writes only this brief and the directory’s inventory/status evidence; it does not publish or submit indexing requests.
