# Project Plate — Architecture (Phase 0)

Source of truth: [`docs/PRODUCT_SPEC.md`](PRODUCT_SPEC.md).

## Inferred architecture

Layered, local-first iPhone app:

| Layer | Responsibility |
|-------|----------------|
| **App** | `@main`, `AppEnvironment`, `AppRouter`, SwiftData container bootstrap |
| **DesignSystem** | Semantic tokens + reusable components (no scattered colors/radii) |
| **Domain** | Models, use cases, protocols (`MealVisionProvider`, `NutritionRepository`, etc.) |
| **Data** | SwiftData persistence, networking, AI, Health, StoreKit adapters |
| **Features** | Onboarding, Today, Scanner, History, Progress, Settings, Paywall |

Dependencies flow inward: Features → Domain protocols ← Data implementations. Views never call URLSession, do nutrition math, or know about OpenAI.

## Phase 0 folder tree

```text
ProjectPlate/
  App/
    ProjectPlateApp.swift
    AppEnvironment.swift
    AppRouter.swift
    RootTabView.swift
  DesignSystem/
    Tokens/{ColorTokens,SpacingTokens,RadiusTokens,TypographyTokens}.swift
    Components/{PrimaryButton,SecondaryButton,MetricCard,MacroProgressView,ConfidencePill}.swift
    Preview/DesignSystemPreviewView.swift
  Domain/
    Models/{MealType,MealConfidence,NutrientSet}.swift
    Protocols/PlaceholderProtocols.swift
  Data/
    Persistence/PersistenceController.swift
  Features/
    Today/TodayView.swift
    History/HistoryView.swift
    Progress/ProgressViewScreen.swift
    Settings/SettingsView.swift
    Scanner/ScannerPlaceholderView.swift
ProjectPlateTests/
  SmokeTests.swift
project.yml          # XcodeGen → ProjectPlate.xcodeproj
docs/PRODUCT_SPEC.md
```

## Technical notes / contradictions to verify on Mac

1. **This Linux Cloud Agent cannot compile SwiftUI.** Open the branch on macOS + Xcode 16+ (iOS 18 SDK) to build/test.
2. Spec references **iOS 27** Apple Foundation Models multimodal APIs as future-gated — Phase 0 does not depend on them.
3. Spec brand palette uses warm off-white `#F5F4EF` and mint `#63E6BE` — followed for iOS (product design system wins over web-agent style defaults).
4. Model IDs (`gpt-5.6-luna`, etc.) stay behind remote config in later phases; not present in Phase 0.
5. Working title remains **Project Plate** until trademark/App Store clearance (do not ship under that name without clearance).

## Phase 0 acceptance (verify on Mac)

- [ ] `xcodegen generate && xcodebuild -scheme ProjectPlate -destination 'platform=iOS Simulator,name=iPhone 16' test`
- [ ] Tabs navigate: Today / History / Progress / Settings
- [ ] Central Scan presents full-screen placeholder and dismisses
- [ ] Design system preview renders light + dark
- [ ] Smoke unit test passes
