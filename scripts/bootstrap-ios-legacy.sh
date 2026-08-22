#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate --spec project-legacy.yml

echo ""
echo "✓ Generated ProjectPlateLegacy.xcodeproj (Xcode 14.2 / iOS 16)"
echo ""
echo "Next steps on your Mac:"
echo "  1. open ProjectPlateLegacy.xcodeproj"
echo "  2. Select scheme: ProjectPlateLegacy"
echo "  3. Pick an iPhone simulator (iOS 16.x) or your iPhone"
echo "  4. Product → Run"
echo ""
echo "Optional: ./scripts/ci-ios-legacy.sh   # command-line build check"
echo ""
echo "When you upgrade to Xcode 16+, use ./scripts/bootstrap-ios.sh for the full app"
echo "(SwiftData, widget, Watch, iCloud sync, unit tests)."
