# Teleprompter Pal competitor comparison format

Owner-approved 21 October 2026. This is the reusable format for future competitor comparisons. The reference implementation is `src/pages/compare/bigvu-alternative.astro`; the directory is `src/pages/compare/index.astro`. Reuse `src/styles/compare.css`, `ComparisonStatus.astro`, the shared header/footer and `offer.ts`. Preserve the existing Figtree, near-black canvas, lavender text, violet actions and actual product icons.

## Page sequence

1. Breadcrumbs, the two app icons, one H1 naming **Teleprompter Pal vs [competitor]**, a short audience-specific recommendation and a pricing action. Show ownership and substantive source-check date.
2. Compact anchor navigation for Features, Pricing, Why choose Teleprompter Pal, When the competitor fits, and Tests & sources.
3. Semantic feature table: feature/short qualification, Teleprompter Pal, competitor. Use green `yes` checks, red `no` crosses and neutral `unknown` dashes through `ComparisonStatus.astro`. Give every status an accessible label. Never turn missing evidence into a red cross. Do not add the removed beta/checked-date table caption. Keep the named, focusable horizontal-scroll region and visible mobile scroll instructions.
4. Pricing immediately after the table, before narrow prose. Two equal columns on desktop, stacked on phones. Put Teleprompter Pal first. Show free limits, actual paid total/billing period, trial eligibility and renewal terms. Distinguish web prices from App Store offers and unequal feature bundles. Do not advertise a yearly-price equivalent as a monthly commitment.
5. Why Teleprompter Pal suits this reader, concrete verified workflow evidence, and when the competitor is a better fit. Position Teleprompter Pal through supported advantages, not invented features, test results or overall superiority.
6. A same-script evaluation exercise, dated plain-text sources/testing limits, native FAQ disclosures, closing pricing action, hub and relevant guide links.

## Facts and sources

Always use the full product name **Teleprompter Pal**, including metadata, alt text and possessives. The owner confirms it is released for iPhone. Scripts, rehearsal, recording, playback, trim/crop and saved edits are free. MP4 export and each Photos/Files/Share delivery require Pro. Approved US subscriptions: $59.99/year with a 3-day trial for eligible subscribers, $19.99/month and $9.99/week. Monthly/weekly plans have no introductory trial. Check `offer.ts` and owner-approved pricing before future publication. No App Store URL is supplied, so do not invent a download button; shared actions/QR lead to the pricing section. The email opt-in remains product updates at `#app-updates`, with its existing backend and privacy anchor.

No outbound competitor links, including nofollow, anywhere in the comparison or related authored guide cluster. Keep readable source names, edition/version/market/date and scope on the page; preserve exact URLs and source snapshots in private research. Owned sites and relevant neutral references are separate from competitor links.

Verify the exact competitor edition, current official pricing and feature gates. Separate hands-on checks from developer claims. Record device, OS, app version and paywall state for testing. An internal development-build test does not certify the public build. Do not claim comparative speed, image quality, voice accuracy or reliability without an appropriate common benchmark. Mark untested items honestly. Avoid private footage and device identifiers in public evidence.

## Hub and publication

Add one crawlable editorial row only when its comparison is finished. Use a short reader decision, both app icons, an internal action and clear evidence/date notes. Keep the broad iPhone roundup as its own destination. A named competitor page serves a different reader decision from the broad shortlist; do not spin out multiple pages for close variants with the same intent.

Each new page needs its own owner publication approval. A format approval does not publish later drafts. Reuse saved SEO research and request budget approval before new paid SEO calls. Preserve current main-branch article/About changes when applying a draft. Build/test appropriate to the change; verify desktop/mobile, table scrolling, FAQs, local links, pricing, source scope, zero competitor links, canonical, robots and sitemap. Follow the existing Git/Vercel and scoped post-deployment IndexNow workflow. Store research, captures and publication receipts privately.
