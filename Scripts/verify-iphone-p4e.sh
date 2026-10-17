#!/usr/bin/env bash
set -euo pipefail
readonly P4E_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly P4E_SIM_ID="${1:?Pass the UDID of an already booted iPhone Simulator.}"
readonly P4E_DERIVED="${P4E_DERIVED:-/tmp/teleprompter-p4e-verify}"
readonly P4E_RESULTS="$(mktemp -d /tmp/teleprompter-p4e-results.XXXXXX)"
export P4E_SIM_ID
xcrun simctl list devices --json | python3 -c '
import json, os, sys
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group]
assert any(d["udid"] == os.environ["P4E_SIM_ID"] and d["state"] == "Booted" and "iPhone" in d["name"] for d in devices), "Choose an already booted iPhone Simulator"
'
cd "$P4E_ROOT"
python3 Scripts/test_iphone_structure.py
swift test --package-path Packages/TeleprompterCore
swift test --package-path Packages/PhoneLibrary
swift test --package-path iPhonePrototype/Support
xcodegen generate --spec project.yml
readonly P4E_XCODE_ARGS=(-project PrivatePresenter.xcodeproj -scheme TeleprompterPhone
  -configuration Debug -destination "platform=iOS Simulator,id=${P4E_SIM_ID}"
  -derivedDataPath "$P4E_DERIVED" CODE_SIGNING_ALLOWED=NO
  -parallel-testing-enabled NO -collect-test-diagnostics never)
xcrun simctl privacy "$P4E_SIM_ID" reset photos-add com.secondwind.teleprompter.prototype
# XCTest's native integration journey accepts either an existing Photos grant
# or its real add-only prompt. UUID fixture roots isolate all scripts/takes.
xcodebuild test "${P4E_XCODE_ARGS[@]}" \
  -only-testing:TeleprompterPhoneTests \
  -only-testing:TeleprompterPhoneUITests/P4EIntegrationFlowTests \
  -resultBundlePath "$P4E_RESULTS/story.xcresult"
# Xcode can return success for a filter matching zero native methods. Require
# the named journey, rather than inferring coverage from its exit status.
xcrun xcresulttool get test-results tests --path "$P4E_RESULTS/story.xcresult" | python3 -c '
import json, sys
def nodes(value):
    if isinstance(value, dict):
        yield value
        for child in value.values(): yield from nodes(child)
    elif isinstance(value, list):
        for child in value: yield from nodes(child)
assert any(n.get("nodeIdentifier", "").startswith("P4EIntegrationFlowTests/testScriptThroughMarkedTake") and n.get("result") == "Passed" for n in nodes(json.load(sys.stdin))), "The P4E native journey did not run and pass"
'
# The deterministic pending-Photos recovery test expects permission established
# by the successful real Photos save in the preceding native journey.
xcodebuild test "${P4E_XCODE_ARGS[@]}" \
  -only-testing:TeleprompterPhoneUITests/P4CExportFlowTests \
  -only-testing:TeleprompterPhoneUITests/P4DDeliveryFlowTests/testDarkLargeLandscapeDestinationsAndFilesCancel \
  -only-testing:TeleprompterPhoneUITests/P4DDeliveryFlowTests/testRecoveryRequiresConfirmationBeforeAnotherPhotosSave \
  -resultBundlePath "$P4E_RESULTS/recovery.xcresult"
xcrun xcresulttool get test-results summary --path "$P4E_RESULTS/recovery.xcresult" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["passedTests"] == 6 and r["failedTests"] == 0 and r["skippedTests"] == 0, r
'
echo "P4E Simulator results: $P4E_RESULTS"
