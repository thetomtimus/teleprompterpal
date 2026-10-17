#!/usr/bin/env bash
set -euo pipefail
readonly P6_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly P6_SIM_ID="${1:?Pass the UDID of an already booted iPhone Simulator.}"
readonly P6_DERIVED="${P6_DERIVED:-/tmp/teleprompter-p6-verify}"
readonly P6_RESULTS="$(mktemp -d /tmp/teleprompter-p6-results.XXXXXX)"
export P6_SIM_ID
xcrun simctl list devices --json | python3 -c '
import json,os,sys
devices=[d for group in json.load(sys.stdin)["devices"].values() for d in group]
assert any(d["udid"] == os.environ["P6_SIM_ID"] and d["state"] == "Booted" and "iPhone" in (d.get("deviceTypeIdentifier", "") + d["name"]) for d in devices), "Choose an already booted iPhone Simulator"
'
cd "$P6_ROOT"
python3 Scripts/test_iphone_structure.py
xcodegen generate --spec project.yml
xcodebuild test -project PrivatePresenter.xcodeproj -scheme TeleprompterPhone \
  -configuration Debug -destination "platform=iOS Simulator,id=${P6_SIM_ID}" \
  -derivedDataPath "$P6_DERIVED" CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:TeleprompterPhoneTests \
  -only-testing:TeleprompterPhoneUITests/P6LibraryFlowTests \
  -only-testing:TeleprompterPhoneUITests/P6BReferenceFlowTests \
  -only-testing:TeleprompterPhoneUITests/TakeLibraryFlowTests \
  -only-testing:TeleprompterPhoneUITests/LibraryFlowTests \
  -only-testing:TeleprompterPhoneUITests/ReaderStudioFlowTests/testManualScrollSettingsAndRotationKeepTransportReachable \
  -only-testing:TeleprompterPhoneUITests/P4EIntegrationFlowTests \
  -resultBundlePath "$P6_RESULTS/library.xcresult"
xcrun xcresulttool get test-results tests --path "$P6_RESULTS/library.xcresult" | python3 -c '
import json,sys
def nodes(value):
    if isinstance(value,dict):
        yield value
        for item in value.values(): yield from nodes(item)
    elif isinstance(value,list):
        for item in value: yield from nodes(item)
tests=[n for n in nodes(json.load(sys.stdin)) if n.get("nodeType") == "Test Case"]
for prefix,count in [("P6BReferenceFlowTests/",3),("P6LibraryFlowTests/",3),("TakeLibraryFlowTests/",3),("LibraryFlowTests/",2),("P4EIntegrationFlowTests/",1),("ReaderStudioFlowTests/",1)]:
    matches=[t for t in tests if t.get("nodeIdentifier", "").startswith(prefix)]
    assert len(matches) == count and all(t.get("result") == "Passed" for t in matches), (prefix,matches)
'
echo "P6 Simulator results: $P6_RESULTS"
