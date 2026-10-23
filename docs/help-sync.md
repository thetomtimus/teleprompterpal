# App changes include help and all seven languages

Owner preference, October 24, 2026: maintaining Teleprompter Pal's app, help instructions, screenshots, and translations is one development task. The owner does not need to request each separately.

## What happens on an app update

The implementing agent reviews the actual app diff against `Marketing/src/data/help.mjs`, updates affected instructions and actual screenshots, and translates changed strings into Spanish, German, French, Brazilian Portuguese, Japanese, and Korean. Existing English remains the source. Root `AGENTS.md` makes this part of every iPhone app task.

The freshness check compares the shipping iPhone sources and reviewed help files to `docs/help-sync-review.json`. Edits, additions, deletions, new screens, shared recording/export changes, and project configuration changes invalidate the review. Test-only changes, Markdown notes, the standalone Mac app, and generated caches do not. Shared translation catalogs are checked too, so even a homepage translation edit may require a quick review because the manual uses those catalogs.

The gate runs in the `App and help stay in sync` GitHub workflow on pull requests and main pushes, in `Scripts/verify-iphone.sh`, and in the TeleprompterPhone target's Release build phase. The phase is generated from `project.yml` by XcodeGen and runs on every Release build, including an archive. Debug builds remain available for iteration. A CI failure reports a failed check; merge protection depends on the repository's rules and is not configured by this workflow. The Release phase itself exits nonzero when the review is stale.

## Completing a change

1. Inspect the changed app behavior and affected articles. Update English instructions and replace screenshots when the displayed controls change. Preserve raw actual app captures and record provenance. For unreleased features, keep documentation with the release branch until publication is appropriate.
2. From `Marketing`, run `npm run translations:extract` and update the affected entries in all six non-English catalogs. Do not add English fallback values.
3. From the repository root, record the completed review. This command builds the website and runs the i18n/help tests before writing any review stamp:

```sh
python3 Scripts/help_sync.py record \
  --outcome updated \
  --reason "Explain the actual behavior change and the matching guide changes." \
  --screenshots "Describe the actual captures replaced or why the existing images still match." \
  --articles record-a-video troubleshooting
```

Use the actual affected slugs from `Marketing/src/data/help.mjs`, or `overview` for the help home page. Node 22.22+ or Node 24, npm, and installed Marketing dependencies are required. `record` makes no translation-service calls: the agent writes and checks translations before running it. A missing translation or failed test prevents the stamp from being written. Changes made while validation runs also prevent stamping.

For an internal fix with no documentation impact, use `--outcome no-help-change`, identify the articles checked, and give a specific reason and screenshot assessment. This avoids meaningless edits while preserving an explicit review. `initial-review` is only allowed when creating the first baseline. Never edit hashes by hand or refresh them simply to silence a failure.

4. Run `python3 Scripts/help_sync.py check`, commit the app/help/translations/screenshots/review together, and follow the authorized app release workflow. Publish and verify the matching help pages in all seven languages before reporting the release complete. Follow `Marketing/docs/seo/indexnow.md` for changed published help URLs.

## What the check proves

The record binds a stated content review and a passing seven-language build/test run to exact source contents. It catches subsequent drift and prevents normal Release builds with an unreviewed app/help combination. It cannot judge whether an instruction is true, invent missing screenshots, detect an uncommitted change on another machine, or deploy the website by itself. Those are the implementing agent's responsibilities in the same task. This is not a scheduled monitor, unattended translator, or guarantee against deliberately removing the gate.

The source boundaries live in `Scripts/help_sync.py`. If the iPhone target gains a new source root or shared package, extend the watched roots in the same change; `project.yml` changes already force a review. Workflow changes themselves should run `python3 Scripts/test_help_sync.py` and regenerate the Xcode project to verify the Release phase remains attached.

## Initial validation

October 24, 2026: the initial review covers 78 shipping app files and the existing nine help topics in all seven languages. The complete website build and nine i18n/help tests passed before recording it. Ten gate tests cover changed, added and deleted app sources, shared services, help/catalog drift, failed translation builds, concurrent edits, and the actual Release shell hook rejecting a stale review while Debug remains available. The existing nine iPhone structure tests pass. XcodeGen attached the phase before compilation, and an unsigned Release build for a generic iOS Simulator completed successfully with the new phase enabled. This verification did not install or upload an app.
