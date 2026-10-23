# Marketing content conventions

For competitor comparisons, follow [the owner-approved comparison format](docs/comparison-format-contract.md) and reuse its shared styles/status component. The approved BIGVU page is the reference implementation. Always write the full name Teleprompter Pal. Keep competitor sources as plain attribution, without outbound competitor hyperlinks, including nofollow. Do not invent a download URL or unsupported product/testing claim. Format approval does not authorize publication of future comparisons.

## Website languages

The owner approved English, Spanish, German, French and Brazilian Portuguese on October 23, 2026. The homepage and pricing page are translated; the other pages remain English. Keep the header chooser and the language links at the very bottom of every public page. Do not change Free Teleprompter Online as part of this workflow.

When editing translated page content or shared navigation, update all four saved translation catalogs in `src/i18n/` in the same change. Run `npm run translations:extract` to write `.translations/source.json`, which lists the exact missing strings by language. Translate new or changed strings with their surrounding source page for context. Preserve the product name, USD amounts, trial conditions, free/Pro limits and clear labeling of English destinations. Unchanged translations should not be regenerated. Do not populate missing translations with English to bypass a build failure.

Client-facing dynamic messages on translated pages must call `translatedMessage` as `t('English message')`, using a single-quoted literal; the build extracts those messages. Add new interactive components to `dynamicMessages()` in `scripts/localize.mjs`. Keep scripts as separate assets for the CSP.

Run `npm run build` and `npm run test:i18n`. The build intentionally refuses missing translations, so English edits cannot silently publish stale localized core pages. This is a Codex-assisted translation workflow with build-time rendering, not a background translation API. No separate translation provider is configured. Use `npm run preview` after building to check localized pages; Astro's development server renders only the English source routes.

To expand coverage, translate the complete page and its interactions first, then add its source path to `translatedRoutes` in `src/i18n/config.mjs`. Never make English fallback pages indexable under language-prefixed URLs. Preserve language-specific canonicals, reciprocal `hreflang`, same-page switching where available, and explicit links to the English version elsewhere.
