#!/usr/bin/env bash
# Build the Xcode 14.2 / iOS 16 legacy target on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: iOS build requires macOS + Xcode (this host is $(uname -s))." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "error: install XcodeGen (brew install xcodegen)" >&2
    exit 1
  fi
fi

xcodegen generate --spec project-legacy.yml

DESTINATION="${DESTINATION:-}"
if [[ -z "$DESTINATION" ]]; then
  if xcrun simctl list devices available | grep -q "iPhone 14"; then
    DESTINATION="platform=iOS Simulator,name=iPhone 14"
  elif xcrun simctl list devices available | grep -q "iPhone SE (3rd generation)"; then
    DESTINATION="platform=iOS Simulator,name=iPhone SE (3rd generation)"
  else
    DESTINATION="generic/platform=iOS Simulator"
  fi
fi

echo "Using destination: $DESTINATION"
echo "Building ProjectPlateLegacy (iOS 16, LEGACY_BUILD)…"

xcodebuild \
  -project ProjectPlateLegacy.xcodeproj \
  -scheme ProjectPlateLegacy \
  -destination "$DESTINATION" \
  -configuration Debug \
  clean build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

echo "Legacy build succeeded."
