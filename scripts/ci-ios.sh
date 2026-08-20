#!/usr/bin/env bash
# Build and test Project Plate on macOS + Xcode.
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

xcodegen generate

# Prefer a concrete iPhone simulator; fall back to generic.
DESTINATION="${DESTINATION:-}"
if [[ -z "$DESTINATION" ]]; then
  if xcrun simctl list devices available | grep -q "iPhone 16"; then
    DESTINATION="platform=iOS Simulator,name=iPhone 16"
  elif xcrun simctl list devices available | grep -q "iPhone 15"; then
    DESTINATION="platform=iOS Simulator,name=iPhone 15"
  else
    DESTINATION="generic/platform=iOS Simulator"
  fi
fi

echo "Using destination: $DESTINATION"

xcodebuild \
  -scheme ProjectPlate \
  -destination "$DESTINATION" \
  -configuration Debug \
  clean build test \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
