# Project Plate (working title)

Native **iPhone** (iPad + Apple Watch glance) AI photo calorie & macro tracker.  
Source of truth: [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) · Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Next stage:** [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md)

> Working title only — do not ship under “Project Plate” without App Store, trademark, domain, and social-handle clearance.

## Requirements

- macOS with **Xcode 16+** (iOS 18 / watchOS 11 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Generate & run (macOS)

```bash
brew install xcodegen
./scripts/bootstrap-ios.sh
open ProjectPlate.xcodeproj
```

Or:

```bash
./scripts/ci-ios.sh
./scripts/release-checklist.sh
```

## Phase status

Engineering through **Phase 38 (meal editor)** is implemented on stacked `cursor/project-plate-phase-*-fc9b` branches (merge order in [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md)). Submit using [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md).

| Band | Phases | Highlights |
|------|--------|------------|
| Foundation | 0–6 | Shell, onboarding, diary, camera mock, catalog, cloud AI gateway, barcode |
| V1 core | 7–11 | Progress, HealthKit, StoreKit Pro, privacy, TestFlight tools |
| V1.1 | 12–20 | Favorites, scan retry, digest, widget, streak, voice, label OCR, Live Activity, iCloud sync |
| V1.2+ | 21–31 | Restaurant matching, adaptive goals, recipes, coach, micros, challenges, iPad, meal plan, Watch, family scaffold |
| Ops | 32–34 | Legal URL overrides, 3.1.2 paywall, Privacy Manifest, consent gate, App Store checklist |
| Power / retention | 35–38 | Custom gateway, reminders, CSV, analytics, target editor, meal editor |

## Cloud AI backend

See [`backend/README.md`](backend/README.md). The client never embeds OpenAI keys.  
Set `PLATE_API_BASE_URL` (and optional `PLATE_API_TOKEN`) in the Xcode target Info to point at a deployed Worker; leave blank for the on-device mock (Simulator / CI default).

## Legal URLs

Set `PLATE_PRIVACY_POLICY_URL` and `PLATE_TERMS_URL` on the Archive scheme before public TestFlight / App Store. Empty values fall back to placeholders and surface a warning in Settings → About.
