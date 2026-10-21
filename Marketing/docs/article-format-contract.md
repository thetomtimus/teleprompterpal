# Teleprompter Pal article-format contract

Approved October 21, 2026 after owner review of desktop and phone previews. Release scope: the shared template and four existing published articles only. Today's portrait/landscape article remains a private draft. This supersedes the October 19 separate-cover geometry for Pal only and applies to future drafts. Source reference: https://openlocalseo.com/blog/how-to-do-local-keyword-research and `/Users/thomas/.codex/skills/daily-search-article/references/article-header-format.md`.

## Shared renderer and invariant content

Use `src/pages/guides/[...id].astro`, `src/components/ArticleSummarizers.astro`, `src/content.config.ts` and `src/styles/guides.css`. Keep Pal's self-hosted Figtree, near-black canvas, lavender links, violet actions and **Teleprompter Pal team** organization byline. The 36px circular TP initials mark is an honest team identity, not a portrait or reviewer badge. Preserve approved prose, headlines, publication/check dates, canonical slugs, schema, contextual links, related reading and private-beta CTAs. A layout or artwork update alone does not set `updated`.

## Header and reading layout

Each article's own image sits behind live HTML breadcrumbs, H1, description, byline/date/read time and summary controls. Do not repeat this decorative cover in the body. Keep the useful opening immediately after the header, followed by useful takeaways, phone contents and body. Original explanatory diagrams and real screenshot labels remain beside the relevant explanation. The app-comparison decision graphic is retained in the body; the separate new still life is the cover.

- Shell maximum 1120px including 24px desktop and 16px phone insets. Title/reading measure maximum 704px; desktop rail 304px with 48px CSS grid gap. Below 1024px, one reading column and the existing native contents disclosure.
- H1: 48px/1.08, weight 700, tracking -0.03em; below 640px, 32px/1.1. Titles wrap naturally and determine header height.
- Header padding 44px top/36px bottom; phones 32px/24px. Stack gaps 20px desktop, 16px phone, followed by a divider 20px below the stack.
- Description: 18px desktop, 15px phone, line-height 28px. Author: 14px semibold, dates/read time 12px; identity mark 36px and row gap 12px. Body and opening: 18px/1.7.
- Cover `object-fit: cover; object-position: center top`. Canvas overlay: OKLCH 70% canvas opacity at 0%, 60% at 55%, solid canvas at 96%. Preserve these stops; inspect text contrast with the actual artwork.
- Above 1440px, cap the centered artwork at 1440px and blend its outer edges into the canvas. The header and overlay remain full width. This prevents wide screens from enlarging equipment beyond the shallow header crop; it does not add header height or change the title measure.

## Four native summary links

ChatGPT: `https://chat.openai.com/?q=`. Perplexity: `https://www.perplexity.ai/search/new?q=`. Claude: `https://claude.ai/new?q=`. Grok: `https://grok.com/?q=`. Each link URL-encodes a request to summarize the article's **own public canonical**, highlight practical takeaways and cite the URL. Provider prefixes were checked against the live approved reference on October 21. No prompt is submitted automatically, no provider API is used, and summary output is not claimed.

Use `target="_blank"` and `rel="noopener noreferrer nofollow"`. Desktop controls: 32px high, 14px text, 16px marks, 4px gaps and 10px horizontal padding. Below 640px: 40x40 icon-only controls with accessible provider names. Preserve focus/hover states. Marks are local assets, with original provenance in `docs/article-summary-provider-marks.json`; these identify providers rather than replace the interface icon system.

A private draft has four disabled buttons and a screen-reader/tooltip explanation. Never construct a summary link from a local URL or expose private prose to a provider. Local previews of already-public articles can use their existing public canonicals.

## Artwork and exports

New decorative covers/thumbnails are topic-specific **people-free** still lifes or objects. No people, faces, hands, silhouettes, portraits or human reflections unless the owner explicitly requests them. Keep Pal's visual world. Remove visible boilerplate illustration disclaimers from decorative imagery. Retain accurate alt metadata, exact prompts, original files and generated provenance privately, plus meaningful labels for screenshots, charts and explanatory/fictional examples.

Use new versioned filenames for revised art. Current published-article candidates use `*-objects-v2-*` with 1600/1000/640px responsive desktop exports, a 900x1600 phone export, a matching 640x361 thumbnail and a 1200x630 social image. `coverImage` carries `src`, `alt`, intrinsic dimensions, responsive `sources` and optional `mobileSrc`. The phone export fits the full source into a top-aligned canvas so the equipment survives tall headers; it is not a tighter destructive crop. The thumbnail may use a closer source crop only when every main object remains intact. Verify the browser's `currentSrc`, loading and actual visible object bounds at desktop and phone widths.

Cover prompts/provenance for the four public article candidates are in `docs/article-header-artwork-v2/`. Today's unapproved draft and its original/generated assets stay in `content-operations/drafts/teleprompterpal.com/`, outside production source/public assets. Matching social-image references must be revised with the visible cover and thumbnail.

## Publication guards and verification

Production article and index collection filters continue to exclude `draft: true`. Related-guide lookup remains published-only. A copied local preview may include draft records only when **both** `VERCEL_ENV=preview` and `PAL_PRIVATE_ARTICLE_PREVIEW=1`; its pages remain noindex/nofollow and summarizers stay disabled for draft records. Do not add private article metadata/assets to production source, public indexes, source-page links or sitemaps.

The owner approved the local desktop/mobile previews and publication of this rollout for the four existing articles. Future daily articles remain drafts for individual review. No schedule, account, provider subscription or site enrollment changes are part of this format update. Verify the production candidate's blog, article routes, canonical/schema/dates, source links, CTA anchors, sitemap, new image hashes, private-route exclusion and required Astro build checks. A local build does not prove live publication.
