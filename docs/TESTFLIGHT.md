# TestFlight readiness (Phase 11)

Use this checklist when cutting a TestFlight build from `main` after merging phase PRs.

## Build

```bash
brew install xcodegen
./scripts/ci-ios.sh
# Archive in Xcode with a real Development Team + HealthKit + StoreKit capabilities.
```

- [ ] Marketing version `1.0.0` (or current RC)
- [ ] Privacy / Terms URLs no longer `example.com`
- [ ] App Store / TestFlight screenshots prepared separately
- [ ] StoreKit products created in App Store Connect (`com.projectplate.pro.monthly`, `.annual`)
- [ ] Managed API base URL + secrets configured if cloud AI is enabled

## Cohort

- Recruit **25–50** users across varied diets and lighting conditions.
- Ask each tester to log ≥5 photo meals in week 1 and send corrections via **Settings → TestFlight tools** or **Send correction** on a saved scan result.

## Metrics to watch

| Signal | Healthy early target |
|--------|----------------------|
| Onboarding completion | >70% |
| First meal save | >50% of installs |
| Correction rate on photo meals | trending **<30%** after prompt/model tweaks |
| Fixture benchmark pass rate | **100%** on `AIBenchmarkRunner` before model swaps |
| Free → paywall | observe only; **do not** enable paywall A/B until D7 retention is credible |

## In-app tools

- **Settings → TestFlight tools → Run fixture benchmark** — offline vision/nutrition regression.
- **Export corrections JSON** — share with the team for prompt/catalog fixes.
- **Paywall A/B toggle** — defaults **off**.

## After TestFlight

1. Fix top correction themes (portion, sauces, mixed bowls).
2. Re-run fixture benchmark + expand real photo set toward the 300-image internal set in the product spec.
3. Only then consider paywall experiments.
