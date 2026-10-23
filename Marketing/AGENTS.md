# Marketing content conventions

For competitor comparisons, follow [the owner-approved comparison format](docs/comparison-format-contract.md) and reuse its shared styles/status component. The approved BIGVU page is the reference implementation. Always write the full name Teleprompter Pal. Keep competitor sources as plain attribution, without outbound competitor hyperlinks, including nofollow. Do not invent a download URL or unsupported product/testing claim. Format approval does not authorize publication of future comparisons.

## Website languages

App changes and the help guide are one task; follow the root `AGENTS.md` and `../docs/help-sync.md`. After changing help content, help screenshots, or a translation catalog, refresh the validated review with `python3 ../Scripts/help_sync.py record` using the documented outcome, reason, screenshot assessment, and article list. It runs the website build and help tests before saving the review. Never update the record without reviewing the relevant content. Unrelated catalog updates may need a `no-help-change` review because catalogs are shared with the manual.

The owner approved English, Spanish, German, French, Brazilian Portuguese, Japanese and Korean on October 23, 2026. The homepage, pricing page, and complete `/help/` manual are translated; editorial `/guides/` and the other pages remain English. Help articles come from `src/data/help.mjs`; adding an article automatically requires all six translations. Keep the header chooser and the language links at the very bottom of every public page. Do not change Free Teleprompter Online as part of this workflow.

When editing translated page content or shared navigation, update every non-English catalog registered in `src/i18n/config.mjs` in the same change. Run `npm run translations:extract` to write `.translations/source.json`, which lists the exact missing strings by language. Translate new or changed strings with their surrounding source page for context. Preserve the product name, USD amounts, trial conditions, free/Pro limits and clear labeling of English destinations. Unchanged translations should not be regenerated. Do not populate missing translations with English to bypass a build failure.

Client-facing dynamic messages on translated pages must call `translatedMessage` as `t('English message')`, using a single-quoted literal; the build extracts those messages. Add new interactive components to `dynamicMessages()` in `scripts/localize.mjs`. Keep scripts as separate assets for the CSP.

Run `npm run build` and `npm run test:i18n`. The build intentionally refuses missing translations, so English edits cannot silently publish stale localized core pages. This is a Codex-assisted translation workflow with build-time rendering, not a background translation API. No separate translation provider is configured. Use `npm run preview` after building to check localized pages; Astro's development server renders only the English source routes.

To expand coverage, translate the complete page and its interactions first, then add its source path to `translatedRoutes` in `src/i18n/config.mjs`. Never make English fallback pages indexable under language-prefixed URLs. Preserve language-specific canonicals, reciprocal `hreflang`, same-page switching where available, and explicit links to the English version elsewhere.
