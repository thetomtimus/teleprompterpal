# P1 iPhone prototype

This is the small feasibility harness from the [reviewed mobile plan](/Users/thomas/Desktop/Projects/Teleprompter/teleprompty/docs/plans/2026-10-14-iphone-product-and-engineering-plan.md). It uses a separate XcodeGen project and the existing portable `TeleprompterCore` types. Mac production source, package manifest and project specification are unchanged. The final `PromptingCore` extraction belongs to P2 after the physical device gate.

## What is implemented

- One editable synthetic script, UIKit reader, elapsed-time scroll engine, pause/restart/manual dragging, pace/font adjustment and a movable/resizable text region.
- Camera service on a dedicated serial actor executor, front/rear 1080p30 SDR H.264 configuration, mirrored front preview and unmirrored MOV output. Camera-specific rotation coordinators orient preview and capture independently. iOS 27 uses the selected fixed orientation; iOS 18–26 freezes the gravity-correct capture angle when a take starts, so hold the phone in the intended orientation first.
- Three-second countdown, prompting from the actual capture-start callback, independent text pause, stop/finalization and non-overlapping take identities.
- Durable pending-take journal, validated ready takes and conservative launch recovery. Incomplete files are retained.
- Playback, trim, centered crop presets, validated MP4 export with progress/cancellation and system file sharing. Original MOV files remain intact.
- A synthetic three-second sample movie with colored quadrants, a moving timing strip and audio pulses. This uses an asset writer solely to generate validation media; camera recording uses movie file output.

The interface is a technical prototype. Detailed Evelize/Sufler parity, full script library/persistence, custom crop gestures, thumbnails, direct Photos delivery, commercial policy, paywalls and production analytics are later phases. No trial or subscription has been created. The take journal is intentionally small; P2/P3 add stronger schema migration, storage cleanup, diagnostics and fault injection.

## Build and simulator validation

Requires the repository's pinned XcodeGen 2.45.4, Xcode with Swift 6 and an iOS Simulator runtime. Current testing uses Xcode 27 / iOS 27 with an iOS 18 deployment target; this does not establish iOS 18 runtime acceptance.

```sh
xcodegen generate --spec iPhonePrototype/project.yml
xcodebuild build -project iPhonePrototype/TeleprompterPrototype.xcodeproj \
  -scheme TeleprompterPrototype -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/teleprompter-p1-derived CODE_SIGNING_ALLOWED=NO

# With the requested Simulator already booted:
bash Scripts/verify-iphone-prototype.sh <simulator-udid>
```

Open the generated project in Xcode to run it, or install the built `.app` with `simctl`. The generated project is ignored. Tap **Sample Take**, adjust trim/crop in **Review take**, then **Export MP4** and **Save or share MP4**. Simulator Camera shows an explicit unavailable message and never simulates a successful capture.

Support tests execute on the host Mac. They cover crop/rotation math, recipe serialization/rejection, journal relaunch, actual MOV-to-MP4 trim/crop, decoded-frame comparisons and preservation of originals after a rejected export. iOS app tests cover the unavailable-camera path, reader clock/pause accounting and brief UIKit deactivation; UI automation covers the sample export flow and prompting controls.

## Opt-in physical runners and local evidence

The separate `TeleprompterPhysical` scheme contains short camera/export, camera/orientation configuration, background/termination and ten-minute scrolling tests. It is excluded from routine Simulator verification. Run one physical test at a time with an unlocked phone; the ten-minute test needs an execution allowance of at least 1,200 seconds. Never treat a Simulator skip as camera acceptance.

If Xcode UI authentication fails over Wi-Fi, the Debug app also accepts explicit launch arguments:

```sh
xcrun devicectl device process launch --device <physical-udid> --terminate-existing \
  com.secondwind.teleprompter.prototype --p1-long-script --p1-probe=short
# Replace short with long for the automatic 600-second front-camera run.
# termination uses a 120-second window for a deliberate external kill while recording.
# Verify recording in diagnostics before sending SIGKILL; relaunch reconciles pending originals.
# standby waits without recording and keeps the active test screen awake for at most five minutes.
# matrix checks front/rear and each selected output orientation while the operator holds the phone.
# short can also accept --p1-camera=rear --p1-orientation=landscapeLeft for a framing retake.
# --p1-resume-matrix keeps validated completed positions when resuming an interrupted matrix.
```

These modes invoke the same model actions as the interface. They request normal system permissions, enforce continuous-reader and output-dimension assertions, and export a trimmed square MP4. They never unlock the phone or change privacy settings. Keep the app visible on the physical phone and disconnect iPhone Mirroring first: the observed mirroring run produced silent media and stalled display ticks even though the media container validated. A completed probe is still subject to decoded video/audio inspection and physical framing/sync checks. Output-orientation selection alone does not prove that the operator physically rotated the phone.

The matrix waits for camera-specific gravity rotation on iOS 27, with a legacy `UIDevice` check on older systems. In this session the latter stayed at portrait during real rotation, and rear gravity tracking also stalled once. An explicit Debug-only `--p1-confirm-position=<orientation>` flag may therefore be used **only after the operator confirms that position**; its report labels the evidence as operator-confirmed. It does not certify automatic detection. The long runner prompts for visible claps near the start and during the final 15 seconds. Keep both hands at chin height in the center of the preview for measurable contact frames.

Local reports live at `Library/Application Support/PromptPrototype/Diagnostics/<take-id>.json`, with a `probe-<mode>.json` stage report alongside the take directory. Reports contain capture format, HDR state, audio port types, thermal state, camera pressure, reader timing/distance, media metadata, export duration, lifecycle events and file-output/session state; they do not contain script text. Thermal state is an OS category, not a measured temperature in degrees. Diagnostic write failure cannot delete or invalidate an original take.

Copy only this app's container with `devicectl device copy from --domain-type appDataContainer --domain-identifier com.secondwind.teleprompter.prototype`. Keep raw movies, screenshots and personal audio outside Git. The local-only [media inspector](/Users/thomas/Desktop/Projects/Teleprompter/teleprompty/Scripts/inspect-iphone-media.swift) measures compressed frame timestamps and decoded audio; the [frame extractor](/Users/thomas/Desktop/Projects/Teleprompter/teleprompty/Scripts/extract-iphone-frames.swift) applies the source track transform for upright frame inspection. Audio peak candidates alone do not establish clap synchronization; match them to decoded visual contact frames.

## Physical P1 gate and subsequent hardening

The prototype is signed and installed on the owner's iPhone 17 Pro / iOS 27.0. The [physical camera report](/Users/thomas/Desktop/Projects/Teleprompter/teleprompty/docs/validation/2026-10-14-iphone17-pro-camera-results.md) records passing ten-minute capture/scrolling, six front/rear orientations, measured ≤100 ms clap sync, trim/crop MP4 export, background save and active SIGKILL recovery. P1 feasibility is complete for this target; installed-reference fidelity and broader P3/P6/release checks remain. Use an unlocked developer-enabled phone and an existing signing team; no physical result is inferred from Simulator testing.

The completed feasibility evidence is in the report above. The following full device checklist also includes later P3/P6 hardening; its broader scenarios are not all claimed as P1-tested.

1. Enter Camera and respond to camera/microphone permissions. Test fresh permission, denial and a subsequent Settings change.
2. Record a ten-minute front-camera 1080p30 take while scrolling. Record short rear-camera and portrait/landscape-left/landscape-right takes. Keep readable text/corner markers in view to check mirroring and framing.
3. Pause/drag/restart the text without stopping capture. Change pace/font/region size near the end of the script. Confirm prompt end leaves recording active and Stop publishes a playable take only after validation.
4. Exercise calls, audio route changes, background/lock, repeated taps, low storage and abrupt termination. Re-enter Camera intentionally after interruption. Inspect launch recovery and retain incomplete media for diagnosis.
5. Inspect original/export codecs, dimensions, duration, audio and decoded framing. Use start/end clap marks to measure A/V sync (within 100 ms). Measure file sizes, export time, reader frame gaps, thermal/system pressure and failure limits. Export a trimmed/cropped MP4 and play it outside the app.
6. Record content-neutral results in `docs/validation`. Store personal scripts/videos outside Git. iOS 18.x and an older supported phone remain separate release coverage requirements.

Script edits are temporary in P1 and reset on a new app launch; script-library autosave is P2 work. Take metadata and media are stored locally and survive relaunch. Uninstalling removes those local takes; shared copies are separate. Do not delete the app during testing if its recorded originals are needed. No recording-length or pricing hypothesis in this prototype is an approved commercial policy.
