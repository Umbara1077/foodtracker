#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen: brew install xcodegen" >&2
  exit 1
fi
xcodegen generate --spec project-legacy.yml
echo "Generated ProjectPlateLegacy.xcodeproj for Xcode 14.2 / iOS 16."
echo "Open ProjectPlateLegacy.xcodeproj and select the ProjectPlateLegacy scheme."
