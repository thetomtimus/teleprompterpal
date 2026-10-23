#!/usr/bin/env bash
set -euo pipefail
readonly P2_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly P2_SIM_ID="${1:?Pass the UDID of an already booted iPhone Simulator.}"
readonly P2_DERIVED="${P2_DERIVED:-/tmp/teleprompter-p2-verify}"
cd "$P2_ROOT"
python3 Scripts/help_sync.py check
python3 Scripts/test_iphone_structure.py
swift test --package-path Packages/TeleprompterCore
swift test --package-path Packages/PhoneLibrary
swift test --package-path iPhonePrototype/Support
xcodegen generate --spec project.yml
xcodebuild build-for-testing -project PrivatePresenter.xcodeproj -scheme PrivatePresenter \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "${P2_DERIVED}-mac" CODE_SIGNING_ALLOWED=NO
xcodebuild test -project PrivatePresenter.xcodeproj -scheme TeleprompterPhone \
  -configuration Debug -destination "platform=iOS Simulator,id=${P2_SIM_ID}" \
  -parallel-testing-enabled NO \
  -derivedDataPath "${P2_DERIVED}-phone" CODE_SIGNING_ALLOWED=NO
