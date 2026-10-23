# Teleprompter Pal app and help maintenance

The owner wants app updates and the public help guide maintained as one task. Do not ask them to request translations or documentation separately.

For every iPhone app change:

1. Review the changed behavior, labels, navigation, permissions, limits, pricing, and recovery flows against `Marketing/src/data/help.mjs`. Read `Marketing/PRODUCT.md` and the affected native implementation; do not infer app behavior from a competitor.
2. Update affected English help instructions in the same change. Add an article for a new task when the existing articles do not cover it. Replace affected screenshots with actual current app captures when controls or layout change, and update `Marketing/docs/asset-provenance.json`. Do not generate or redraw app screenshots.
3. Update the affected Spanish, German, French, Brazilian Portuguese, Japanese, and Korean catalog entries. Follow `Marketing/AGENTS.md`. Preserve actual app control names and product facts. Do not use English fallback text to pass checks.
4. Run the documented help review command in `docs/help-sync.md`. It builds every language and runs the help/i18n tests before saving a review record. Record the affected articles and the screenshot review. For an internal fix with no user-facing change, record a specific `no-help-change` explanation instead of making unnecessary copy changes.
5. Commit the app change, help changes, translations, screenshot provenance, and `docs/help-sync-review.json` together. For an authorized release, publish and verify the matching help pages in all seven languages as part of that release. Do not describe an app release as complete while its corresponding help update is still unpublished. For unreleased features, keep matching help work in the release branch until it is appropriate to publish.

`python3 Scripts/help_sync.py check` detects additions, edits, and deletions in the shipping iPhone source, shared phone packages, app configuration, and reviewed help assets/catalogs. It runs in GitHub CI and standard iPhone Release builds. Never refresh the review record just to suppress a failure: inspect the diff and reconcile the guide first. Debug builds remain available while working.

This is an agent-maintained workflow with automated freshness and translation checks, not an unattended translation service. A hash check proves a review is current, not that the prose is semantically correct. Do the actual review. Changes from another developer still need to pass the same checks.

## Content style

For blog drafts or revisions, start with a concrete observation, misconception, or decision. Avoid generic introductions, heavy em dashes, repeated tidy scaffolding, and polished filler. Prefer specific practitioner language.
