# Teleprompter Pal marketing site

Platform: Astro static website. Audience: people preparing talking videos on iPhone.

Prepare a script, rehearse with adjustable scrolling, record while reading, then trim, crop, export an MP4 and save or share. Scripts and original recordings stay on the iPhone. No account is required for this workflow. The app supports iOS 18 and later.

The owner confirmed this site should focus on the iPhone app. The Mac app comes later. The website borrows measured design primitives and layout language from https://detail.co/, with original product content, the approved Teleprompter Pal icon and existing project imagery.

Use release-focused iPhone app copy. Do not invent a trial, pricing, testimonials, awards, AI scripting, automatic editing or speech-following. The central CTA and QR code share the product-updates signup destination in src/data/site.ts. The owner requested an email-only signup that saves addresses using the simplest free option. Submissions go directly to the existing Second Wind HubSpot account’s Teleprompter Pal Early Access form, with no separate database or account required. Preserve the site’s existing publication workflow.

The separate ../Website contains the existing published privacy and support sources. Preserve that directory and native app sources. The marketing build links to those existing live policy and support URLs.


## Product naming and release wording (owner instruction, 21 October 2026)

Always use the full product name **Teleprompter Pal**, including possessives, headings, metadata, alt text and comparisons. Do not shorten it. Describe Teleprompter Pal as an iPhone app, without private-beta or prerelease positioning. This owner instruction supersedes earlier availability language in this document. Do not invent a price, App Store URL, device-test result or unimplemented feature. Until a real App Store destination is provided, the existing email form is labelled product updates; do not label that form as a download.

## Owner preference: illustration captions · October 21, 2026

Do not add visible AI-generation or provenance credit captions beneath illustrations. The owner explicitly removed the About portrait caption and asked that this kind of caption not be used again. Keep useful descriptive alt text and generation/source records outside the visitor-facing copy.

## Search publishing notifications · October 21, 2026

After a production deployment adds or substantively updates a public page, use the scoped `scripts/submit_indexnow.py` command described in `docs/seo/indexnow.md`. Run its dry-run preflight, then submit only the explicit changed canonical URLs and save the response outside public files. Do not submit private drafts, the noindex reader, unchanged inventory or cosmetic-only edits. This command notifies participating search engines; it does not replace Google Search Console or prove indexing.
