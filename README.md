# Project Plate (working title)

Native **iPhone** AI photo calorie & macro tracker.  
Source of truth: [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) · Phase notes: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

> Working title only — do not ship under “Project Plate” without App Store, trademark, domain, and social-handle clearance.

## Requirements

- macOS with **Xcode 16+** (iOS 18 SDK)
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
```

## Phase status

- **Phase 0** — App shell, design system (CI verified)
- **Phase 1** — Onboarding + targets (CI verified)
- **Phase 2** — Local diary / Quick Add / History (CI verified)
- **Phase 3** — Camera scan + mock analysis → review → save (CI verified)
- **Phase 4** — Nutrition catalog search + food editor; scan resolves via catalog
- **Next: Phase 5** — Cloud AI meal analysis backend
