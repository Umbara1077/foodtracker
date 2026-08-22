#!/usr/bin/env bash
# Generate ProjectPlate.xcodeproj from project.yml.
#
#   ./scripts/bootstrap-ios.sh              full app (iPhone + widget + Apple Watch)
#   ./scripts/bootstrap-ios.sh --no-watch   iPhone + widget only (no watchOS SDK required)
set -euo pipefail
cd "$(dirname "$0")/.."

NO_WATCH=0
for arg in "$@"; do
  case "$arg" in
    --no-watch) NO_WATCH=1 ;;
    -h|--help)
      sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen: brew install xcodegen" >&2
  exit 1
fi

if [[ "$NO_WATCH" -eq 0 ]]; then
  xcodegen generate
  echo "Generated ProjectPlate.xcodeproj — open it in Xcode or run xcodebuild."
  exit 0
fi

# Derive a watch-free spec from project.yml so the two never drift.
# The spec must live in the repo root: XcodeGen resolves source paths
# relative to the spec file's own directory.
SPEC=".projectplate-nowatch.yml"
trap 'rm -f "$SPEC"' EXIT

awk '
  # drop the whole ProjectPlateWatch target block
  /^  ProjectPlateWatch:[[:space:]]*$/            { skip_target=1; next }
  skip_target && /^  [^ ]/                        { skip_target=0 }
  skip_target                                     { next }
  # drop the watch dependency entry and its continuation lines
  /^      - target: ProjectPlateWatch[[:space:]]*$/ { skip_dep=1; next }
  skip_dep && /^        /                         { next }
  skip_dep                                        { skip_dep=0 }
  # drop the watch target from the scheme build list
  /^        ProjectPlateWatch: all[[:space:]]*$/  { next }
  { print }
' project.yml > "$SPEC"

if grep -q "ProjectPlateWatch" "$SPEC"; then
  echo "error: could not strip the Watch target — project.yml layout changed." >&2
  echo "       Install the watchOS SDK instead (Xcode ▸ Settings ▸ Components)." >&2
  exit 1
fi

xcodegen generate --spec "$SPEC"
echo "Generated ProjectPlate.xcodeproj WITHOUT the Apple Watch target."
echo "No watchOS SDK needed. Re-run without --no-watch once you install it."
