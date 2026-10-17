#!/usr/bin/env bash
set -euo pipefail
readonly P5_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly P5_SIM_ID="${1:?Pass the UDID of an already booted iPhone Simulator.}"
readonly P5_DERIVED="${P5_DERIVED:-/tmp/teleprompter-p5-verify}"
readonly P5_RESULTS="$(mktemp -d /tmp/teleprompter-p5-results.XXXXXX)"
export P5_SIM_ID
xcrun simctl list devices --json | python3 -c '
import json, os, sys
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group]
assert any(d["udid"] == os.environ["P5_SIM_ID"] and d["state"] == "Booted" and "iPhone" in d["name"] for d in devices), "Choose an already booted iPhone Simulator"
'
cd "$P5_ROOT"
python3 Scripts/test_iphone_structure.py
xcodegen generate --spec project.yml
# This separate scheme supplies Xcode interception as well as the fixture catalog.
# Running a StoreKit test without it can open an unwanted sandbox authentication prompt.
xcodebuild test -project PrivatePresenter.xcodeproj -scheme TeleprompterPhone-P5 \
  -configuration Debug -destination "platform=iOS Simulator,id=${P5_SIM_ID}" \
  -derivedDataPath "$P5_DERIVED" CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:TeleprompterPhoneTests -resultBundlePath "$P5_RESULTS/app-host.xcresult"
xcrun xcresulttool get test-results tests --path "$P5_RESULTS/app-host.xcresult" | python3 -c '
import json, sys
def nodes(value):
    if isinstance(value, dict):
        yield value
        for child in value.values(): yield from nodes(child)
    elif isinstance(value, list):
        for child in value: yield from nodes(child)
cases = [n for n in nodes(json.load(sys.stdin)) if n.get("nodeType") == "Test Case"]
assert cases and all(n.get("result") == "Passed" for n in cases), "An app-host test failed or was skipped"
required = {
 "nativeCatalogPurchaseAndRestoreUseVerifiedStoreKitState()",
 "renewalExpiryAndRefundArriveThroughSignedState()",
 "pendingDoesNotUnlockAndApprovalUpdatesWithoutAnotherPurchase()",
 "cancelledResultAndCancelledErrorDoNotGrantAccess()",
 "nativeStoreFailureDoesNotGrantAccess()",
 "unavailableCatalogAndRestoreFailurePreserveSignedLocalAccessAcrossModelRestart()",
 "unverifiedPurchaseCannotUnlockAndRestoreReportsNoneTruthfully()",
 "duplicatePurchaseRequestsProduceOnlyOneTransaction()",
 "nativeBillingGraceUsesVerifiedRenewalDeadline()",
 "purchaseExpiryAndRefundCannotStopAnAcceptedTakeOrBlockTheNextOne()",
 "pendingApprovalAndStoreFailuresKeepCaptureEditsAndExportAvailable()",
 "uncertainUnconfiguredAndGraceAccessDoNotGateNewRecordings(fixture:)",
 "purchaseEventsDeduplicateApprovalAndKeepRestoreSeparateFromRenewal()",
 "cancelledUnverifiedFailedAndEmptyRestoreEventsNeverClaimPurchaseSuccess()",
}
actual = {n.get("name") for n in cases if n.get("nodeIdentifier", "").startswith("SubscriptionStoreKitTests/")}
assert required <= actual, "A required local StoreKit case did not execute"
assert sum(n.get("nodeIdentifier", "").startswith("SubscriptionAccessTests/") for n in cases) >= 5, "Access policy tests did not execute"
assert sum(n.get("nodeIdentifier", "").startswith("SubscriptionPresentationTests/") for n in cases) >= 3, "Subscription terms tests did not execute"
assert sum(n.get("nodeIdentifier", "").startswith("LocalEventTests/") for n in cases) >= 11, "Local event tests did not execute"
print("Verified", len(cases), "app-host tests including every required StoreKit case")
'
xcodebuild test -project PrivatePresenter.xcodeproj -scheme TeleprompterPhone-P5 \
  -configuration Debug -destination "platform=iOS Simulator,id=${P5_SIM_ID}" \
  -derivedDataPath "$P5_DERIVED" CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:TeleprompterPhoneUITests/P5BSubscriptionFlowTests \
  -only-testing:TeleprompterPhoneUITests/P5CSubscriptionPolicyFlowTests \
  -only-testing:TeleprompterPhoneUITests/P5DLocalEventFlowTests \
  -only-testing:TeleprompterPhoneUITests/LibraryFlowTests/testCreateEditSearchReaderAndRelaunchPreserveUnicode \
  -only-testing:TeleprompterPhoneUITests/LibraryFlowTests/testFilesImportDuplicateDeleteAndRestore \
  -only-testing:TeleprompterPhoneUITests/P4EIntegrationFlowTests \
  -resultBundlePath "$P5_RESULTS/subscription-ui.xcresult" | tee "$P5_RESULTS/subscription-ui.log"
xcrun xcresulttool get test-results tests --path "$P5_RESULTS/subscription-ui.xcresult" | python3 -c '
import json, sys
def nodes(value):
    if isinstance(value, dict):
        yield value
        for child in value.values(): yield from nodes(child)
    elif isinstance(value, list):
        for child in value: yield from nodes(child)
cases = [n for n in nodes(json.load(sys.stdin)) if n.get("nodeType") == "Test Case"]
required = {
 "testPlansDisclosuresCloseAndExistingExportRemainAvailable()",
 "testNativePurchaseRelaunchRestoreAndSubscriptionManagement()",
 "testPendingApprovalUpdatesWithoutRepurchase()",
 "testNativePaymentSheetCancellationKeepsThePaywallDismissible()",
 "testNoPurchaseRestoreAndUnconfiguredBuildAreHonest()",
 "testCatalogPurchaseAndRestoreFailuresCanBeRetried()",
 "testUnverifiedPurchaseNeverClaimsActiveAccess()",
 "testDarkLargeLandscapePlansAndActionsRemainReachable()",
 "testSubscriptionChangesDuringTakeKeepRecordingAndEditedExportAvailable()",
 "testUnavailableAndUnconfiguredBillingStillAllowNewTakes()",
 "testScriptPurchaseCaptureAllDestinationsAndRelaunch()",
 "testCancelledExportAndUnknownDeliveryRecoverWithoutFalseSuccess()",
 "testCreateEditSearchReaderAndRelaunchPreserveUnicode()",
 "testFilesImportDuplicateDeleteAndRestore()",
 "testScriptThroughMarkedTakeTrimCropAllDestinationsAndRelaunch()",
}
assert {n.get("name") for n in cases} == required, "A required subscription UI case did not execute"
assert all(n.get("result") == "Passed" for n in cases), "A subscription UI test failed or was skipped"
print("Verified all", len(cases), "subscription UI journeys")
'
readonly P5_CONTAINER="$(xcrun simctl get_app_container "$P5_SIM_ID" com.secondwind.teleprompter.prototype data)"
python3 Scripts/verify_p5d_events.py "$P5_CONTAINER" "$P5_RESULTS/subscription-ui.log" > "$P5_RESULTS/local-events.json"
xcodebuild build -project PrivatePresenter.xcodeproj -scheme TeleprompterPhone \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$P5_DERIVED" CODE_SIGNING_ALLOWED=NO
readonly P5_RELEASE_APP="$P5_DERIVED/Build/Products/Release-iphonesimulator/TeleprompterPhone.app"
python3 - "$P5_RELEASE_APP" <<'PY'
from pathlib import Path
import sys
app = Path(sys.argv[1])
assert app.is_dir()
assert not list(app.rglob("*.storekit")), "Local catalog leaked into Release"
assert not list(app.rglob("*StoreKitTest*")), "StoreKitTest leaked into Release"
assert b"local.teleprompter.pro." not in (app / "TeleprompterPhone").read_bytes(), "Test product IDs leaked into Release"
print("Release app contains no local StoreKit catalog, framework or product IDs")
PY
echo "P5A/P5B/P5C/P5D Simulator results: $P5_RESULTS"
