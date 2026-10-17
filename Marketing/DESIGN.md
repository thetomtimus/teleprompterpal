---
name: Teleprompter Pal Marketing
description: A luminous, device-led marketing system for the iPhone teleprompter.
colors:
  primary: "#8f67ff"
  primary-deep: "#6136d9"
  lavender: "#c3aaff"
  canvas: "#0f0f0f"
  text: "#fff"
  display: "rgba(246,237,255,.92)"
  muted: "rgba(255,255,255,.75)"
  quiet: "#a6a3ad"
  rule: "rgba(255,255,255,.12)"
  rehearsal-panel: "#17161d"
  format-idle: "#27232f"
  format-selected: "#6241ab"
typography:
  display:
    fontFamily: "Figtree, sans-serif"
    fontSize: "130px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-3px"
  display-mobile:
    fontFamily: "Figtree, sans-serif"
    fontSize: "56px"
    fontWeight: 700
    lineHeight: "56px"
    letterSpacing: "-1.5px"
  headline:
    fontFamily: "Figtree, sans-serif"
    fontSize: "48px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-1px"
  headline-mobile:
    fontFamily: "Figtree, sans-serif"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.7px"
  hero-body:
    fontFamily: "Figtree, sans-serif"
    fontSize: "28px"
    fontWeight: 400
    lineHeight: "42px"
  body:
    fontFamily: "Figtree, sans-serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.5
  feature-body:
    fontFamily: "Figtree, sans-serif"
    fontSize: "20px"
    fontWeight: 400
    lineHeight: "30px"
  nav:
    fontFamily: "Figtree, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: "19.2px"
  button:
    fontFamily: "Figtree, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: "24px"
  button-compact:
    fontFamily: "Figtree, sans-serif"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: "16px"
  qr-caption:
    fontFamily: "Caveat, cursive"
    fontSize: "28px"
    fontWeight: 400
    lineHeight: "33.6px"
rounded:
  control: "80px"
  panel: "24px"
  panel-mobile: "20px"
  phone: "40px"
  native-figure: "33px"
  chip: "30px"
  qr: "15px"
spacing:
  section: "160px"
  section-tablet: "120px"
  section-mobile: "88px"
  gap: "56px"
  gap-mobile: "40px"
  action: "24px"
  feature: "80px"
components:
  button-primary:
    textColor: "{colors.text}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "21px 32px 22px"
  button-compact:
    textColor: "{colors.text}"
    typography: "{typography.button-compact}"
    rounded: "{rounded.control}"
    padding: "12px 16px"
  demo-action:
    textColor: "{colors.text}"
    padding: "0"
  rehearsal-panel:
    backgroundColor: "{colors.rehearsal-panel}"
    rounded: "{rounded.panel}"
  navigation:
    typography: "{typography.nav}"
    textColor: "{colors.text}"
  format-chip:
    backgroundColor: "{colors.format-idle}"
    textColor: "{colors.muted}"
    rounded: "{rounded.chip}"
    padding: "10px 15px"
  format-chip-selected:
    backgroundColor: "{colors.format-selected}"
    textColor: "{colors.text}"
  faq-disclosure:
    textColor: "{colors.text}"
    padding: "22px 0"
---

# Design System: Teleprompter Pal Marketing

## Overview

**Creative North Star: "The Rehearsal Stage"**

The Rehearsal Stage places luminous words and recognizable iPhone screens on a near-black canvas. The owner selected Detail’s measured visual language: Figtree, lavender-white display type, violet gradient pills, broad section spacing, and device-led compositions. The result is direct, spacious, and lightly theatrical, with the approved lavender ring icon retaining the app’s identity.

Depth comes from a restrained combination of dark tonal panels, device shadows, and violet light. The handwritten QR annotation adds one informal voice beside precise sans-serif type. Controls feel rounded and tactile; supporting labels stay quiet so the words, product imagery, and actions carry the hierarchy.

This specification belongs only to the Astro marketing site in Marketing/. It does not replace the native iPhone app’s design tokens or the parent project’s design documentation. Preserve the approved app icon and the actual native UI shown in screenshots.

**Key Characteristics:**

- Near-black canvas with lavender-white display type and violet accents.
- Large Figtree headings, quiet explanatory copy, and open vertical rhythm.
- Rounded gradient actions, dark demonstration panels, and phone silhouettes.
- Caveat reserved for the QR annotation; native system type reserved for illustrative app chrome.

The implementation is the source of truth: `src/styles/global.css`, `src/components/`, and `src/pages/index.astro`. The measured reference and intentional adaptations are recorded in `docs/detail-reference.md`; the home composition contract remains in `.impeccable/surfaces/home.md`. Extracted on October 17, 2026. The metaphor names the implemented world; it is documentation, not a newly selected direction.

## Colors

The palette uses violet as an action and light source against neutral darkness. Frontmatter values preserve the source CSS formats, including translucent whites.

### Primary

- **Bright Violet** (`primary`): the leading end of the primary action gradient, range-input accent, and handwritten QR annotation.
- **Deep Violet** (`primary-deep`): the trailing end of the action gradient and the skip-link background.
- **Soft Lavender** (`lavender`): quiet links, selected UI details, reassurance icons, and the shared focus outline.

### Neutral

- **Stage Black** (`canvas`): the main page canvas and dark QR modules.
- **Clear White** (`text`): primary text and action labels.
- **Luminous Lavender White** (`display`): the hero display and secondary lines of section headings. The hero’s final word has the local highlight `#fff1ff`.
- **Soft White** (`muted`): supporting copy, secondary actions, and labels.
- **Quiet Gray** (`quiet`): availability, captions, footer links, and small explanatory text.
- **Hairline White** (`rule`): subtle dividers around reassurance, privacy, FAQ, and footer content.
- **Rehearsal Ink** (`rehearsal-panel`): the browser demonstration’s shared enclosure.
- **Format Ink** (`format-idle`): unselected aspect-ratio controls.
- **Selected Violet Ink** (`format-selected`): the pressed aspect-ratio control. This is a local component state rather than another brand accent family.

**The Violet Action Rule.** Use the violet gradient for prominent actions and lavender for quiet links, focus, and selected details. Keep dark surfaces dominant.

## Typography

**Display Font:** Figtree (sans-serif fallback).
**Body Font:** Figtree (sans-serif fallback).
**Annotation Font:** Caveat (cursive fallback).
**Illustrative App UI Font:** the platform system stack (`-apple-system`, `BlinkMacSystemFont`, `Segoe UI`, sans-serif).

Figtree is self-hosted as a variable font (weights 300–900); the marketing hierarchy uses its open shapes and strong 700-weight headings. Caveat is self-hosted at 400 and appears only around the QR code. Both font licenses live in `public/fonts/`.

### Hierarchy

- **Display:** the frontmatter’s `display` is the base desktop hero. Keep its unit line-height, tight tracking, and luminous text shadow. It is a single semantic H1.
- **Headline:** `headline` is the base section heading. Workflow and closing headings use a larger local desktop size (60px / 1.1); FAQ uses a local size (40px / 44px).
- **Title:** demo controls use a local bold title (32px / 1.15, −0.7px tracking); it becomes (28px / 1.1) on mobile.
- **Body:** `body` is the page default, `feature-body` is explanatory section copy, and `hero-body` is the hero’s supporting line. The hero measure is capped at 800px; the section-intro paragraph at 390px in the base layout.
- **Navigation and action labels:** use the explicit `nav`, `button`, and `button-compact` roles. Tiny app-preview labels remain visually subordinate.
- **QR annotation:** `qr-caption` uses a small counterclockwise tilt (−4deg), with a separate handwritten arrow (29px / 25px, −14deg).

### Responsive display behavior

The measured reference endpoints are 130px / 130px on desktop and 56px / 56px on mobile. The implementation deliberately adapts between them; **130px is not the value at every desktop or tablet width**.

| Viewport condition | Implemented hero type |
| --- | --- |
| Above 1399px | Base `display`: 130px, line-height 1, −3px tracking |
| At or below 1399px | `clamp(90px, 8.65vw, 130px)`, line-height 1 |
| At or below 959px | `clamp(66px, 8.6vw, 90px)`, line-height 1, −2px tracking |
| At or below 767px | `display-mobile`: 56px / 56px, −1.5px tracking; final word becomes a separate line |
| At or below 374px | Local small-phone correction: 49px / 51px |

Feature headings also adapt (48px base; 44px at 1399px; 40px at 1199px; 36px at 959px; 32px at 767px). Mobile hero copy is (19px / 28.5px), or (18px) at the smallest breakpoint. Feature copy becomes (18px / 27px). These are code overrides, not additional inferred scale steps.

**The Three Voices Rule.** Use Figtree for marketing, Caveat for the QR annotation, and the system stack for illustrative app UI. Preserve typography inside actual screenshots.

## Layout

The main content uses a centered container (`min(1140px, calc(100% - 80px))`). Its total side allowance becomes 64px at 959px, 48px at 767px, and 36px at 374px. The hero copy has a wider base measure (`min(1302px, calc(100% - 64px))`), while its device stage is capped at 1100px. These exceptions support the display and product imagery without widening normal reading columns.

The desktop header is 88px high. Hero copy begins after a 20px top inset; supporting copy and actions each use a 24px top gap. This compact first-view stack is intentional. The three phones enter the first viewport with recognizable content. Below the first view, the reusable section interval is `section`, reduced to `section-tablet` at 1199px and `section-mobile` at 767px. The named `gap` and `gap-mobile` CSS properties are declared reference primitives; several actual layouts use local gaps, so do not assume those variables drive every separation.

The browser rehearsal uses a (1.3fr / 1fr) split, changing to (1.1fr / 1fr) at 959px and one column at 767px. Feature rows and the export area use paired columns, with local gaps stepping from 80px to 50px and then 32px or 40px. Features and export stack on mobile, with meaningful reading order retained. FAQ changes from paired columns to a single column at 959px.

At 767px the header becomes 80px tall and navigation moves to a native disclosure menu. The CTA keeps a 44px touch target. Mobile hero actions stack, the phone trio stays centered inside a deliberately clipped stage, and side devices remain partially visible. That stage crop must not create document-level horizontal overflow. At or below 374px the compact header CTA is hidden to preserve room for the wordmark and menu.

The desktop QR floats at the lower right. Its art is 136px in the base layout, 112px at 1399px, and the floating treatment disappears at 1199px. The closing QR remains available and moves into normal document flow at that breakpoint. The floating QR fades when the closing section enters view. At 1600px the desktop navigation gap expands from its base 36px to 48px; intermediate breakpoints tighten it to 24px and 20px.

## Elevation & Depth

Depth combines local ambient light, tactile action edges, dark tonal panels, and substantial device shadows. The black footer is a separate closing plane. Text glow is a display treatment; the reader demo relies on contrast and a soft guide band instead.

### Shadow Vocabulary

- **Primary action:** `0 10px 20px rgba(0,0,0,.1), inset -3px -3px 2px -4px rgba(255,255,255,.89), inset 3px 2px 2px -3px #fff`. It produces the pill’s small ambient lift and fine light edges.
- **Display light:** `0 0 10px rgba(175,89,255,.85), 0 0 3px rgba(255,255,255,.85), 0 10px 32px rgba(34,0,255,.42), 0 10px 32px rgba(0,0,0,.2)`. This is a text shadow on the hero.
- **Phone frame:** `0 28px 55px -16px rgba(0,0,0,.7), inset 0 0 0 1px #77727c`. It separates the hero devices from the stage.
- **Native figure:** `0 30px 60px -20px #0009`. It grounds the larger feature screenshots.
- **Rehearsal panel:** `0 28px 80px -35px rgba(0,0,0,.6)`. It lifts the demonstration enclosure without an accent outline.

The exact primary gradient is `linear-gradient(90deg,#8f67ff 0%,#6136d9 100%)`. It cannot be expressed by the frontmatter’s `backgroundColor` field, so the full background and shadow live in the component sidecar. The compact header action uses its own translucent violet gradient and shallower light edges.

**The Local Light Rule.** Concentrate glow on the display heading and device stage. Keep reading panels and supporting text clear rather than adding a glow to every surface.

## Shapes

Actions are long pills using `control`; circular restart is a true circle (52px square). Rehearsal enclosures use `panel`, becoming `panel-mobile` on mobile. Aspect-ratio controls and visual captions use `chip`. The square QR artwork has the softer `qr` corner.

Hero phone frames use `phone`, a narrow dark border (5px), and a tall (640 / 1391) aspect ratio. Their radius adapts to 34px at 959px and 32px at 767px, with a 4px mobile border. Larger native screenshots use `native-figure`. The phone silhouette and shallow device rotations give the media its physical character; preserve the pixels of the source screenshots inside that framing.

Dividers are single translucent rules. The crop demonstration adds precise white corners and a thirds guide. These local tools are visual explanations of a video workflow, not a border style to spread through marketing text.

## Components

### Buttons

Rounded and tactile. The primary uses the exact gradient and shadow in Elevation & Depth, Clear White text, the `button` role, and the frontmatter padding. Its base minimum height is 68px. On mobile it becomes (21px / 24px), with a 62px minimum height and padding (18px 28px 19px). The browser demo transport has its own smaller treatment (18px / 20px, minimum 52px).

The compact header variant is 40px high in the base layout and uses its translucent gradient. On mobile its minimum height increases to 44px and its label becomes 12px. The quiet demo action is an inline icon and text link with a 44px base minimum height, becoming 36px on mobile.

Shared pill hover brightens (1.13) and moves upward (−2px); active moves downward (1px) and scales (0.98). Transitions last 0.2s and use the declared outward easing for transforms. Disabled buttons use opacity (0.45) and a disallowed cursor. All interactive elements receive the shared visible focus outline (3px Soft Lavender, 6px offset).

### Chips

Aspect-ratio controls use Format Ink and Soft White at rest, then Selected Violet Ink and Clear White when `aria-pressed="true"`. They have a 44px minimum height. Hover uses the local violet surface (`#4c376c`). Selection is exclusive across the group; the nearby format label and illustrative crop update together.

### Cards / Containers

The rehearsal panel is the canonical large enclosure. Its left side uses a dark violet gradient (`#282135` to `#18161f`) with 28px padding; the right control area uses 42px padding. Those values adapt to (24px / 30px) at 959px and (23px 20px 20px / 28px) on mobile. The demonstration viewport is 340px tall, or 300px on mobile, with a soft top-and-bottom mask and a translucent lavender reading guide.

### Inputs / Fields

The site uses native range inputs, not text-entry fields. Ranges are full width, 24px high, and use Bright Violet as `accent-color`. Visible labels pair with tabular numeric outputs. Pace spans 10–90 in steps of 5; text size spans 24–44 in steps of 2. Preserve native keyboard adjustment and the shared visible focus treatment. The current implementation has no error-field design to document.

### Navigation

Desktop navigation is quiet Figtree with hover text in Soft Lavender. The approved icon and compact wordmark anchor the header. Mobile uses a native `details` / `summary` disclosure with a 44px menu target, a 220px dark violet panel (`#25212e`), a 16px corner, and 12px padding. Links close the menu after selection; Escape closes it and returns focus to the summary. Footer navigation is quieter and stacks beneath the wordmark on mobile.

### FAQ Disclosures

Native details elements use single bottom rules, a spacious summary, and a caret that turns (180deg) when open. Open summaries become Soft Lavender. Answer text is quieter with generous leading (1.65). Preserve the disclosure semantics instead of replacing them with decorative row containers.

### Device Previews and QR Annotation

The center camera device is wider than its neighbors (294px against 242px in the base layout). Side phones rotate (−8deg / 8deg); on mobile those become (−9deg / 9deg). Feature screenshots use shallow alternating rotations (−5deg / 5deg).

The Scripts, editor, and reader-settings imagery are actual iPhone app screenshots. The presenter is an existing fictional image; camera chrome, editing preview, and crop demonstration are illustrative. The browser rehearsal is a controllable website demo. Preserve those disclosures in captions and accessible text.

The handwritten QR caption, arrow, white art tile, and quiet “Opens your email app” note form one annotation. Both QR copies and every early-access action read the same value from `src/data/site.ts`. During private beta that value is an explicit email request, not an install promise.

Movement is brief and state-driven. The default transform easing is `cubic-bezier(.16,1,.3,1)`. Reduced-motion preference disables CSS transitions and animations, removes button/QR hover transforms, and disables smooth scrolling. Rehearsal text moves only after the user presses Play; it pauses when hidden or outside the viewport.

## Do's and Don'ts

### Do:

- **Do** preserve the approved lavender ring app icon and the native screenshots’ original UI.
- **Do** use the code’s responsive typography and container overrides when extending the marketing site.
- **Do** keep keyboard focus visible and preserve the reduced-motion treatment.
- **Do** label actual app screenshots and illustrative previews honestly.
- **Do** keep the CTA and QR code bound to the same destination in src/data/site.ts.

### Don’t:

- **Don’t** apply this marketing specification to the parent native app or replace its tokens.
- **Don’t** replace the owner’s pinned Detail direction with another visual world.
- **Don’t** use Caveat for navigation, long copy, or primary actions.
- **Don’t** crop away the meaningful app content when adapting device compositions.
- **Don’t** present the illustrative camera, editing, browser rehearsal, or format preview as an actual app screenshot.
