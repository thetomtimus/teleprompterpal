#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROTOTYPE_ROOT="${REPO_ROOT}/iPhonePrototype"
readonly PROTOTYPE_SIM_ID="${1:?Pass the UDID of an already booted iPhone Simulator.}"
readonly PROTOTYPE_DERIVED_DATA="${PROTOTYPE_DERIVED_DATA:-/tmp/teleprompter-p1-derived}"

# Simulator startup is an explicit user action; this script only verifies the selected target.
xcrun simctl list devices booted --json | python3 -c '
import json,sys
udid=sys.argv[1]
devices=json.load(sys.stdin)["devices"]
if not any(d["udid"] == udid and d["state"] == "Booted" for group in devices.values() for d in group):
    sys.exit("Selected Simulator is not booted.")
' "$PROTOTYPE_SIM_ID"

swift test --package-path "${PROTOTYPE_ROOT}/Support"
xcodegen generate --spec "${PROTOTYPE_ROOT}/project.yml"
xcodebuild test -project "${PROTOTYPE_ROOT}/TeleprompterPrototype.xcodeproj" \
  -scheme TeleprompterPrototype -configuration Debug \
  -destination "platform=iOS Simulator,id=${PROTOTYPE_SIM_ID}" \
  -derivedDataPath "$PROTOTYPE_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO
