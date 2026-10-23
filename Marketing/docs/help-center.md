# Teleprompter Pal help center

Updated October 24, 2026. Official task documentation at `/help/`: eight articles and a getting-started page in English, Spanish, German, French, Brazilian Portuguese, Japanese, and Korean. These 63 pages are separate from editorial `/guides/`.

The finalization adds 14 current native app screenshots and four silent demonstrations beside their relevant instructions. Clips show rehearsal, recording controls, trimming, and cropping. The export article now shows preparation, all three delivery destinations, and the Photos success state. The old colored test-clip images are removed. Both language choosers preserve the current article.

## Content and evidence

`src/data/help.mjs` is the English source. `HelpLayout.astro` supplies navigation and local search. `HelpMedia.astro` renders proportional screenshots and native video players with controls, inline playback, no autoplay, `preload="none"`, and a full-size link. Written steps and captions describe each silent demonstration. Images link to full-size originals. New or changed text requires all six translations before release.

Instructions and captures use shipping native source at revision `c7d74775d7eec16c1953f631d7c4528ed77d6929`, app version 0.6.12 (32). No shipping app behavior was changed. The opt-in `iPhoneUITests/HelpGuideCaptureTests.swift` suite exercises the actual app on a dedicated iPhone 17 / iOS 27 Simulator. All three tests passed: import/rehearsal, recording, and trim/crop/delivery. The last test saved to Photos and Files and opened the system share sheet.

These are real native UI captures, not generated or composited interfaces. Camera recording uses the existing `SimulatorCaptureController`: the preview is blank and the take simulated. Every language explains this limitation. This is not a physical-device or recording-quality test. Screen labels remain English; instructions, captions, media labels, and links are translated. Website coverage does not claim seven-language native app support.

The editing example is an 18-second excerpt of [Bees on flowers by J. M. Pearson](https://commons.wikimedia.org/wiki/File:Bees_on_flowers.webm), CC0 1.0. It was loaded into isolated test data, not filmed with the app. A silent AAC track makes it compatible with the media pipeline. Asset origins, attachment names, time intervals, and hashes are in `docs/asset-provenance.json`; every new WebP also embeds its origin. The overview retains the previously documented real script-library screenshot.

## Keeping all languages current

Follow root `AGENTS.md` and [the app/help freshness gate](../../docs/help-sync.md). App changes, help updates, screenshots, and translations are one task. Update affected English instructions, run `npm run translations:extract`, translate new or changed keys in every catalog, and replace media whose controls changed. From the repository root run `python3 Scripts/help_sync.py record` with the affected articles and a specific screenshot assessment. It builds every locale, runs help/i18n tests, and saves the review. CI and standard iPhone Release builds reject a stale review.

The gate includes `HelpMedia.astro`, all help assets including MP4s, and all six catalogs. Tests verify localized descriptions, asset existence, accessible full-size links, and user-controlled video playback. This is agent-maintained work with automated checks, not an unattended translation or documentation service. The implementing agent must review changes; matching hashes cannot prove semantic accuracy. The owner should not need to request help updates or translations separately when requesting app changes.

## Refreshing native captures

Use a dedicated simulator with disposable fixtures, built from the revision being documented. Never seed a personal simulator or capture another branch's unreleased UI. The capture suite skips unless `TEST_RUNNER_PAL_HELP_CAPTURE=1` reaches the test runner.

Fixture identifiers:

- Root: `8D47F5E6-3E86-4C8C-9503-87E4ACB12345`
- Script: `F8C1B54D-B22D-4A43-986D-8E8F4D109123`
- Sample take: `C40B0001-1111-4444-8888-123456789012`

After installing the Debug app, resolve its current data container using `xcrun simctl get_app_container DEVICE_ID com.secondwind.teleprompter.prototype data`. Prepare a normal schema-1 script library at `Library/Application Support/PhoneScripts/UITests/ROOT_ID/library.json`, with an authored short sample titled `Garden update`, and the same text in `Documents/Garden update.txt`. Seed a schema-2 catalog at `Library/Caches/PhoneCaptureTests/ROOT_ID/Takes/takes.json`, referencing `TAKE_ID.mov` in that directory: ready state, 18 seconds, 1280×720, H.264/AAC. Use the IDs above. Reset only this dedicated fixture's saved edit/delivery state before a repeat run. Check current storage models before reseeding if schemas changed. The October 24 fixture contains no user data.

Generate the Xcode project with `xcodegen generate`, then run:

```sh
TEST_RUNNER_PAL_HELP_CAPTURE=1 xcodebuild \
  -project PrivatePresenter.xcodeproj -scheme TeleprompterPhone \
  -configuration Debug -destination 'platform=iOS Simulator,id=DEVICE_ID' \
  -derivedDataPath /tmp/pal-help-capture-build \
  -resultBundlePath /tmp/pal-help-capture.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:TeleprompterPhoneUITests/HelpGuideCaptureTests \
  CODE_SIGNING_ALLOWED=NO test
xcrun xcresulttool export attachments \
  --path /tmp/pal-help-capture.xcresult \
  --output-path /tmp/pal-help-attachments --filter '*.png'
```

For demonstrations, start `xcrun simctl io DEVICE_ID recordVideo --codec=h264 /tmp/pal-help-walkthrough.mov` before the suite and stop it cleanly with SIGINT. Logs include `HELP_MARK` timestamps to locate actions. Verify actual frames: simulator video has variable timing, so wall-clock offsets alone are insufficient. Keep complete actions and outcomes. Encode with FFmpeg `trim=start=START:end=END,setpts=PTS-STARTPTS,scale=720:-2,fps=30`, H.264/yuv420p, no audio, and `+faststart`. Inspect clips from beginning to end. Resize screenshots proportionally to 720px WebP without redrawing controls. Update captions, embedded origins, hashes, and translations together.

Raw captures, XCTest results, attachment manifest, and clip intervals are retained privately under the repository root's `.impeccable/review/help-final/`. Browser evidence is under `Marketing/.impeccable/review/help-final/`. Large raw recordings and test bundles are not deployed.

## Verification and publication

The final design review returned **ship**, with no material fixes after refreshing three captures taken during initial media loading. All seven languages were visually checked at 1440px desktop and 390px phone widths. The build checks 379 source strings across seven locales. All ten help/i18n tests and ten freshness-gate tests passed. This is not an independent native-speaker audit of every translation.

For each release, run the validated review, verify playback/navigation in the browser, and check deployed pages, media, canonical/hreflang tags, and sitemap. Submit only substantively changed help URLs to IndexNow once after deployment. Receipt does not establish indexing or rankings. The initial guide was published October 24 from `bb4c8486ad7ded6e1f418c32723e662519af9e14`; this finalization's production receipt is recorded after deployment.
