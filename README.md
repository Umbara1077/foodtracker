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

## Phase status

- **Phase 0** — App shell, design system, Scan placeholder (CI verified)
- **Phase 1** — Onboarding + Mifflin–St Jeor targets (CI verified)
- **Phase 2** — Local diary: Quick Add, Today meals, History day strip
- **Next: Phase 3** — Camera capture + mocked analysis → result screen
