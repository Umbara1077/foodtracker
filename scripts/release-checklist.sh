#!/usr/bin/env bash
# Engineering checklist before cutting a TestFlight / App Store build.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Project Plate release readiness =="
echo

fail=0

version=$(python3 - <<'PY'
import re
text=open("project.yml").read()
m=re.search(r'MARKETING_VERSION:\s*"([^"]+)"', text)
b=re.search(r'CURRENT_PROJECT_VERSION:\s*"([^"]+)"', text)
print(f"{m.group(1) if m else '?'} ({b.group(1) if b else '?'})")
PY
)
echo "Marketing version: $version"

if rg -n "example\.com/project-plate" ProjectPlate --glob '!**/RecipeURLImporter.swift' >/tmp/plate-legal-hits.txt; then
  echo
  echo "WARN: placeholder legal hosts still referenced in app sources:"
  cat /tmp/plate-legal-hits.txt
  echo "  → Set INFOPLIST_KEY_PLATE_PRIVACY_POLICY_URL / PLATE_TERMS_URL for the Archive scheme."
else
  echo "OK: no hard-coded project-plate example.com legal paths in app sources."
fi

if ! rg -n "com\.projectplate\.pro\.(monthly|annual)" ProjectPlate ProjectPlate/Resources/Products.storekit >/dev/null; then
  echo "FAIL: StoreKit product IDs missing"
  fail=1
else
  echo "OK: StoreKit product IDs present (com.projectplate.pro.monthly / .annual)"
fi

if [[ ! -f docs/TESTFLIGHT.md ]]; then
  echo "FAIL: docs/TESTFLIGHT.md missing"
  fail=1
else
  echo "OK: docs/TESTFLIGHT.md present"
fi

echo
echo "Human blockers (cannot be completed in this repo alone):"
echo "  [ ] Merge phase PR stack into main (see docs/TESTFLIGHT.md)"
echo "  [ ] Development Team + signing + HealthKit/CloudKit/App Groups capabilities"
echo "  [ ] Real privacy + terms hosts in Archive Info.plist"
echo "  [ ] App Store Connect IAP products + screenshots"
echo "  [ ] Enable iCloud.com.projectplate.app container for device sync"
echo "  [ ] Working-title / trademark clearance before public naming"
echo "  [ ] Recruit TestFlight cohort (25–50)"
echo

if [[ "$fail" -ne 0 ]]; then
  echo "Release readiness script found blocking issues."
  exit 1
fi

echo "Engineering gate: PASS (human checklist still required)."
