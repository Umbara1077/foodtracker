# Next stage: TestFlight handoff

Engineering feature work through **V1.2+ (Phases 0–31)** is on branch tips with green CI. This document is the handoff into **human / App Store ops**.

Current tip marketing version: **1.5.10** (build 45) — Haptics on `cursor/project-plate-phase-45-haptics-fc9b`.

## 1. Merge order (draft PRs → `main`)

Merge **oldest → newest** so each PR’s tip includes prior phases:

| Order | PR theme | Branch suffix |
|------:|----------|---------------|
| 1 | Phase 7 Progress | `phase-7` |
| 2 | Phase 8 Health | `phase-8` |
| 3 | Phase 9 Paywall | `phase-9` |
| 4 | Phase 10 Privacy | `phase-10` |
| 5 | Phase 11 TestFlight tools | `phase-11` |
| 6 | Phase 12 Favorites | `phase-12-favorites` |
| 7 | Phase 13 Scan retry | `phase-13-scan-retry` |
| 8 | Phase 14 Weekly digest | `phase-14-weekly-digest` |
| 9 | Phase 15 Widget | `phase-15-widget` |
| 10 | Phase 16 Streak | `phase-16-streak` |
| 11 | Phase 17 Voice | `phase-17-voice` |
| 12 | Phase 18 Label OCR | `phase-18-label-ocr` |
| 13 | Phase 19 Live Activity | `phase-19-live-activity` |
| 14 | Phase 20 iCloud sync | `phase-20-icloud-sync` |
| 15 | Phase 21 Restaurant | `phase-21-restaurant` |
| 16 | Phase 22 Adaptive goals | `phase-22-adaptive-goals` |
| 17 | Phase 23 Recipe URL | `phase-23-recipe-url` |
| 18 | Phase 24 Recipe builder | `phase-24-recipe-builder` |
| 19 | Phase 25 Coach | `phase-25-coach-insights` |
| 20 | Phase 26 Micronutrients | `phase-26-micronutrients` |
| 21 | Phase 27 Challenges | `phase-27-challenges` |
| 22 | Phase 28 iPad | `phase-28-ipad-layout` |
| 23 | Phase 29 Meal plan | `phase-29-meal-plan` |
| 24 | Phase 30 Apple Watch | `phase-30-apple-watch` |
| 25 | Phase 31 Family plan | `phase-31-family-plan` |
| 26 | Phase 32 TestFlight ready | `phase-32-testflight-ready` |
| 27 | Phase 33 App Review billing | `phase-33-app-review-billing` |
| 28 | Phase 34 App Store compliance | `phase-34-app-store-compliance` |
| 29 | Phase 35 Gateway / reminders / CSV | `phase-35-gateway-reminders` |
| 30 | Phase 36 A11y / analytics | `phase-36-a11y-analytics` |
| 31 | Phase 37 Target editor | `phase-37-target-editor` |
| 32 | Phase 38 Meal editor | `phase-38-meal-editor` |
| 33 | Phase 39 Copy previous day | `phase-39-copy-day` |
| 34 | Phase 40 Share day summary | `phase-40-share-day` |
| 35 | Phase 41 Today date picker | `phase-41-today-date` |
| 36 | Phase 42 Undo meal delete | `phase-42-undo-delete` |
| 37 | Phase 43 Scan primary CTA | `phase-43-scan-cta` |
| 38 | Phase 44 History meal search | `phase-44-history-search` |
| 39 | Phase 45 Haptics | `phase-45-haptics` |

After merges, cut the Archive from `main`. Full human checklist: [`docs/APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md).

## 2. Build (engineering)

```bash
brew install xcodegen
./scripts/ci-ios.sh
./scripts/release-checklist.sh
# Archive in Xcode with a real Development Team.
```

Capabilities required on the App ID / provisioning:

- HealthKit
- App Groups (`group.com.projectplate.app`)
- iCloud / CloudKit (`iCloud.com.projectplate.app`) — enable container in Apple Developer
- Push / Live Activities (as configured)
- Associated Watch app

## 3. Legal URLs (required before public TF / App Store)

Defaults still fall back to `example.com` placeholders. For Archive / TestFlight builds set:

| Info.plist key | Purpose |
|----------------|---------|
| `PLATE_PRIVACY_POLICY_URL` | Canonical privacy policy |
| `PLATE_TERMS_URL` | Canonical terms of use |

Empty values keep the placeholder (Settings → About warns when placeholders are active).

## 4. Human checklist (outside this repo)

- [ ] Merge PR stack into `main` (table above)
- [ ] Development Team + signing for App + Widget + Watch
- [ ] Real privacy + terms hosts in the Archive scheme
- [ ] App Store Connect IAP: `com.projectplate.pro.monthly`, `com.projectplate.pro.annual`
- [ ] Confirm paywall shows price/period, auto-renew copy, Privacy + Terms links, Restore, Manage subscription
- [ ] TestFlight / App Store screenshots
- [ ] CloudKit container enabled for device sync
- [ ] Working-title / trademark / domain clearance before public naming
- [ ] Optional: deploy Cloudflare Worker + set `PLATE_API_BASE_URL` / `PLATE_API_TOKEN`
- [ ] Recruit **25–50** TestFlight testers

## 5. Cohort guidance

- Ask each tester to log ≥5 photo meals in week 1.
- Collect corrections via **Settings → TestFlight tools** or **Send correction** on a scan result.
- Keep **paywall A/B off** until D7 retention is credible.

## 6. Metrics to watch

| Signal | Healthy early target |
|--------|----------------------|
| Onboarding completion | >70% |
| First meal save | >50% of installs |
| Correction rate on photo meals | trending **<30%** after prompt/model tweaks |
| Fixture benchmark pass rate | **100%** on `AIBenchmarkRunner` before model swaps |
| Free → paywall | observe only |

## 7. In-app tools

- **Settings → TestFlight tools → Run fixture benchmark** — offline vision/nutrition regression.
- **Export corrections JSON** — share for prompt/catalog fixes.
- **Paywall A/B toggle** — defaults **off**.

## 8. After first TestFlight wave

1. Fix top correction themes (portion, sauces, mixed bowls).
2. Re-run fixture benchmark; expand toward the 300-image internal set in the product spec.
3. Only then consider paywall experiments.
4. Public App Store submission after legal URLs, screenshots, IAP, and brand clearance.
