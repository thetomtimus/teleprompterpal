# Website language publishing

October 23, 2026. Scope: Teleprompter Pal only.

## Published coverage

| Language | Homepage | Pricing | Help manual |
| --- | --- | --- | --- |
| English | `/` | `/pricing/` | `/help/` |
| Spanish | `/es/` | `/es/pricing/` | `/es/help/` |
| German | `/de/` | `/de/pricing/` | `/de/help/` |
| French | `/fr/` | `/fr/pricing/` | `/fr/help/` |
| Brazilian Portuguese | `/pt-br/` | `/pt-br/pricing/` | `/pt-br/help/` |
| Japanese | `/ja/` | `/ja/pricing/` | `/ja/help/` |
| Korean | `/ko/` | `/ko/pricing/` | `/ko/help/` |

The header has a keyboard-accessible language disclosure. The footer ends with the seven native language names. On translated pages, changing language preserves the page. On English-only editorial guides, comparisons, tools, About, privacy and support, the chooser says it links to translated homepages. Links from translated pages to English content carry a language label. The existing app screenshots stay in English, identified in the caption. This website release does not localize the iPhone app or promise app-language support.

## One source layout, saved translations

Astro renders the existing English templates. `scripts/localize.mjs` parses every complete route listed in the locale configuration, translates text and accessibility/SEO attributes from saved JSON catalogs, rewrites eligible internal links, rebuilds localized QR codes, and adds matching canonicals and reciprocal language annotations. Script, SVG and native-language-picker contents are excluded from translation. There is no runtime translation request, cookie, IP redirect or extra tracking.

The post-build step then inventories all public routes for the sitemap and applies the existing CSP and preview-indexing rules. Localized pages are only generated after every catalog passes validation. English URLs and existing articles remain stable.

## Updating content

1. Edit the English source as normal.
2. Run `npm run translations:extract`. The output `.translations/source.json` lists source strings, dynamic messages, and missing strings per locale.
3. Update only affected entries in `src/i18n/es.json`, `de.json`, `fr.json`, `pt-BR.json`, `ja.json`, and `ko.json`. Read the entire sentence around inline markup and the surrounding page before translating. Do not change commercial facts or insert HTML.
4. Run `npm run build` and `npm run test:i18n`. Review affected interactive states using `npm run preview`.
5. For help changes, also run `node --test tests/help.test.mjs` and check the affected instructions against the app. See `docs/help-center.md`.
6. Commit English and all affected translations together; publish through the existing main-branch Vercel deployment.

The exact English source text is the translation key. A changed paragraph becomes a missing key, so the build stops until it has been translated. Existing translations are reused. Layout-only edits rebuild all languages without retranslation. Deleted keys may be removed after confirming no source uses them. Keep intentionally untranslated product names in the explicit allowlist.

The workflow is assisted by Codex and enforced in `AGENTS.md` and the build. **Automatic background draft generation is not connected to a translation provider.** A future service integration would need an explicitly configured credential and a review policy. Builds currently make no translation-service calls and incur no translation-service fees.

## Quality and limits

Initial translations were authored and checked by Codex, not certified by native-language reviewers. USD values are deliberately retained with the existing local-App-Store-price disclosure. Critical pricing or feature corrections ship in the same deployment in all configured languages. A translation failure fails the build and leaves the previous Vercel deployment live. This also means English copy changes must include translations before release.

Search engines can discover the new URLs through internal links, reciprocal `hreflang` and the sitemap. Publishing or sitemap inclusion does not guarantee indexing, ranking or traffic. No automatic SEO background schedule was created.
