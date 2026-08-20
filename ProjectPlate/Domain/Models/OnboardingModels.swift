import Foundation

enum UnitSystem: String, Codable, Sendable, CaseIterable {
    case us
    case metric
}

enum GoalType: String, Codable, Sendable, CaseIterable, Identifiable {
    case loseWeight
    case maintainWeight
    case gainWeight
    case trackOnly

    var id: Self { self }

    var title: String {
        switch self {
        case .loseWeight: "Lose weight"
        case .maintainWeight: "Maintain weight"
        case .gainWeight: "Gain weight"
        case .trackOnly: "Track nutrition only"
        }
    }

    var subtitle: String {
        switch self {
        case .loseWeight: "A steady calorie target below maintenance."
        case .maintainWeight: "Match estimated maintenance calories."
        case .gainWeight: "A controlled surplus for building."
        case .trackOnly: "Skip prescriptions — set targets yourself."
        }
    }

    var systemImage: String {
        switch self {
        case .loseWeight: "arrow.down.circle"
        case .maintainWeight: "equal.circle"
        case .gainWeight: "arrow.up.circle"
        case .trackOnly: "list.bullet.clipboard"
        }
    }
}

enum ActivityLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case mostlySeated
    case lightlyActive
    case active
    case veryActive

    var id: Self { self }

    var title: String {
        switch self {
        case .mostlySeated: "Mostly seated"
        case .lightlyActive: "Lightly active"
        case .active: "Active"
        case .veryActive: "Very active"
        }
    }

    /// Spec §10.9 / §21.2 — store the multiplier on the profile.
    var multiplier: Double {
        switch self {
        case .mostlySeated: 1.20
        case .lightlyActive: 1.375
        case .active: 1.55
        case .veryActive: 1.725
        }
    }
}

enum PacePreference: String, Codable, Sendable, CaseIterable, Identifiable {
    case slow
    case moderate
    case faster

    var id: Self { self }

    var title: String {
        switch self {
        case .slow: "Slow"
        case .moderate: "Moderate"
        case .faster: "Faster"
        }
    }
}

enum FormulaSex: String, Codable, Sendable, CaseIterable, Identifiable {
    case maleEquation
    case femaleEquation
    case skipManual

    var id: Self { self }

    var title: String {
        switch self {
        case .maleEquation: "Male equation"
        case .femaleEquation: "Female equation"
        case .skipManual: "Skip and set calories manually"
        }
    }
}

enum MacroPreference: String, Codable, Sendable, CaseIterable, Identifiable {
    case balanced
    case higherProtein
    case lowerCarb
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .higherProtein: "Higher protein"
        case .lowerCarb: "Lower carb"
        case .custom: "Custom"
        }
    }

    /// Protein / carbs / fat calorie shares. Spec §10.11.
    var ratios: (protein: Double, carbs: Double, fat: Double) {
        switch self {
        case .balanced: (0.25, 0.45, 0.30)
        case .higherProtein: (0.30, 0.40, 0.30)
        case .lowerCarb: (0.30, 0.30, 0.40)
        case .custom: (0.25, 0.45, 0.30)
        }
    }
}

enum TargetSource: String, Codable, Sendable {
    case onboardingEstimate
    case manual
    case defaultPlaceholder
}

struct NutritionTargetSnapshot: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var effectiveDate: Date
    var calories: Int
    var proteinGrams: Int
    var carbGrams: Int
    var fatGrams: Int
    var source: TargetSource

    init(
        id: UUID = UUID(),
        effectiveDate: Date = .now,
        calories: Int,
        proteinGrams: Int,
        carbGrams: Int,
        fatGrams: Int,
        source: TargetSource
    ) {
        self.id = id
        self.effectiveDate = effectiveDate
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.source = source
    }
}

struct UserProfile: Codable, Sendable, Equatable {
    var id: UUID
    var createdAt: Date
    var unitSystem: UnitSystem
    var age: Int?
    var heightCm: Double?
    var currentWeightKg: Double?
    var targetWeightKg: Double?
    var goalType: GoalType
    var activityMultiplier: Double
    var formulaSex: FormulaSex?
    var macroPreference: MacroPreference
    var onboardingComplete: Bool
    var cloudAIConsentVersion: String?
    var healthKitEnabled: Bool

    static let blank = UserProfile(
        id: UUID(),
        createdAt: .now,
        unitSystem: .metric,
        age: nil,
        heightCm: nil,
        currentWeightKg: nil,
        targetWeightKg: nil,
        goalType: .maintainWeight,
        activityMultiplier: ActivityLevel.lightlyActive.multiplier,
        formulaSex: nil,
        macroPreference: .balanced,
        onboardingComplete: false,
        cloudAIConsentVersion: nil,
        healthKitEnabled: false
    )
}
