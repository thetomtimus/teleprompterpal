#!/usr/bin/env bash
set -euo pipefail
readonly P6C_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly P6C_LARGE="${1:?Pass the booted large iPhone Simulator UDID}"
readonly P6C_COMPACT="${2:?Pass the booted compact iPhone Simulator UDID}"
readonly P6C_DERIVED="${P6C_DERIVED:-/tmp/teleprompter-p6c-verify}"
readonly P6C_RESULTS="$(mktemp -d /tmp/teleprompter-p6c-results.XXXXXX)"
export P6C_LARGE P6C_COMPACT
trap 'printf "P6C evidence: %s\n" "$P6C_RESULTS"' EXIT
cd "$P6C_ROOT"
xcrun simctl list devices --json | python3 -c '
import json,os,sys
items=[d for group in json.load(sys.stdin)["devices"].values() for d in group]
for key in ("P6C_LARGE","P6C_COMPACT"):
    assert any(d["udid"] == os.environ[key] and d["state"] == "Booted" and "iPhone" in d.get("deviceTypeIdentifier", "") for d in items), "Use two booted iPhone Simulators"
assert os.environ["P6C_LARGE"] != os.environ["P6C_COMPACT"], "Use distinct Simulators"
'
# The VoiceOver test temporarily enables the service and restores off through
# XCTest teardown, including on failure. Do not change a user's on preference.
for P6C_DEVICE in "$P6C_LARGE" "$P6C_COMPACT"; do
  if ! xcrun devicectl device info voiceover --device "$P6C_DEVICE" --timeout 10 | rg -q 'currently disabled'; then
    printf 'Begin this isolated QA run with Simulator VoiceOver off. The native speech test needs iOS 27+.\n' >&2
    exit 1
  fi
done
python3 Scripts/test_iphone_structure.py
xcodegen generate --spec project.yml
export TELEPROMPTER_LOCAL_STOREKIT_TEST=1
xcodebuild build-for-testing -project PrivatePresenter.xcodeproj -scheme TeleprompterPhone-P5 \
  -destination "platform=iOS Simulator,id=$P6C_LARGE" -derivedDataPath "$P6C_DERIVED" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
P6C_RUNS=("$P6C_DERIVED"/Build/Products/TeleprompterPhone-P5_iphonesimulator*.xctestrun)
[[ ${#P6C_RUNS[@]} -eq 1 && -f "${P6C_RUNS[0]}" ]]
readonly P6C_RUN="${P6C_RUNS[0]}"
# Keep the StoreKit daemon cases serial; do not share a Simulator with another run.
xcodebuild test-without-building -xctestrun "$P6C_RUN" \
  -destination "platform=iOS Simulator,id=$P6C_COMPACT" -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:TeleprompterPhoneTests -resultBundlePath "$P6C_RESULTS/host.xcresult"
xcrun simctl privacy "$P6C_LARGE" reset photos-add com.secondwind.teleprompter.prototype
xcodebuild test-without-building -xctestrun "$P6C_RUN" \
  -destination "platform=iOS Simulator,id=$P6C_LARGE" -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:TeleprompterPhoneUITests/P6CHardeningFlowTests \
  -only-testing:TeleprompterPhoneUITests/P6LibraryFlowTests/testFirstUseRecordSelectionAndSettings \
  -only-testing:TeleprompterPhoneUITests/P4CExportFlowTests/testProgressCancelRetryAndLandscapeReady \
  -only-testing:TeleprompterPhoneUITests/P4CExportFlowTests/testTerminationAndBackgroundRequireDeliberateRetry \
  -only-testing:TeleprompterPhoneUITests/P4DDeliveryFlowTests/testPhotosPermissionDenialKeepsFilesAndShareAvailable \
  -resultBundlePath "$P6C_RESULTS/large.xcresult"
xcodebuild test-without-building -xctestrun "$P6C_RUN" \
  -destination "platform=iOS Simulator,id=$P6C_COMPACT" -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:TeleprompterPhoneUITests/P6BReferenceFlowTests \
  -only-testing:TeleprompterPhoneUITests/P6CHardeningFlowTests/testNativeAccessibilityAudit \
  -only-testing:TeleprompterPhoneUITests/P4BCropFlowTests/testDarkAccessibilityCropControls \
  -only-testing:TeleprompterPhoneUITests/P4CExportFlowTests/testLowSpaceRetryDarkAccessibility \
  -only-testing:TeleprompterPhoneUITests/P4EIntegrationFlowTests \
  -resultBundlePath "$P6C_RESULTS/compact.xcresult"
for P6C_PAIR in host:97 large:6 compact:7; do
  P6C_NAME="${P6C_PAIR%:*}" P6C_COUNT="${P6C_PAIR#*:}"
  xcrun xcresulttool get test-results summary --path "$P6C_RESULTS/$P6C_NAME.xcresult" > "$P6C_RESULTS/$P6C_NAME-summary.json"
  python3 - "$P6C_RESULTS/$P6C_NAME-summary.json" "$P6C_COUNT" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
assert result['result'] == 'Passed' and result['passedTests'] == int(sys.argv[2]) and result['failedTests'] == 0 and result['skippedTests'] == 0, result
PY
done
