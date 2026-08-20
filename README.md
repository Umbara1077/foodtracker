# Project Plate (working title)

Native **iPhone** AI photo calorie & macro tracker.  
Source of truth: [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) · Phase notes: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

> Working title only — do not ship under “Project Plate” without App Store, trademark, domain, and social-handle clearance.

## Requirements

- macOS with **Xcode 16+** (iOS 18 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

This repository was scaffolded on a Linux Cloud Agent, which **cannot** compile SwiftUI. Generate and build on a Mac.

## Generate & run (macOS)

```bash
brew install xcodegen
./scripts/bootstrap-ios.sh
open ProjectPlate.xcodeproj
```

Or build + test from the CLI (same path CI uses):

```bash
./scripts/ci-ios.sh
```

## CI

GitHub Actions (macOS-15) runs `xcodegen generate` then `xcodebuild build test` on every push/PR.
## Phase 0 status

Implemented:
- SwiftUI app shell + tab navigation (Today / History / Progress / Settings)
- Elevated central **Scan** action → full-screen placeholder
- Design-system tokens (colors light/dark, spacing, radius, typography)
- Components: PrimaryButton, SecondaryButton, MetricCard, MacroProgressView, ConfidencePill
- Debug DesignSystemPreviewView (Settings → Design system gallery)
- SwiftData container placeholder (`UserProfile`, `NutritionTarget`)
- `AppEnvironment` dependency container
- Unit smoke tests (Swift Testing)

Not in Phase 0 (by design): camera, AI, HealthKit, StoreKit, Firebase.

## Next (Phase 1)

Onboarding flow + Mifflin–St Jeor target calculator with unit tests — see PRODUCT_SPEC §10 and §82.
