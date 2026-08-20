import Foundation

/// Deterministic Mifflin–St Jeor + macro math (PRODUCT_SPEC §21).
enum TargetCalculator {
    struct Input: Equatable, Sendable {
        var weightKg: Double
        var heightCm: Double
        var age: Int
        var formulaSex: FormulaSex
        var activityMultiplier: Double
        var goalType: GoalType
        var pace: PacePreference
        var macroPreference: MacroPreference
        /// Optional manual calorie override (track-only / skip formula / edit result).
        var manualCalories: Int?
    }

    struct Output: Equatable, Sendable {
        var bmr: Double
        var tdee: Double
        var calories: Int
        var proteinGrams: Int
        var carbGrams: Int
        var fatGrams: Int
        var source: TargetSource
        var isEstimate: Bool
    }

    static func bmr(weightKg: Double, heightCm: Double, age: Int, formulaSex: FormulaSex) -> Double? {
        guard formulaSex != .skipManual else { return nil }
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch formulaSex {
        case .maleEquation: return base + 5
        case .femaleEquation: return base - 161
        case .skipManual: return nil
        }
    }

    static func goalFactor(goalType: GoalType, pace: PacePreference) -> Double {
        switch goalType {
        case .maintainWeight, .trackOnly:
            return 1.0
        case .loseWeight:
            switch pace {
            case .slow: return 0.90
            case .moderate: return 0.85
            case .faster: return 0.80
            }
        case .gainWeight:
            switch pace {
            case .slow: return 1.05
            case .moderate: return 1.10
            case .faster: return 1.15
            }
        }
    }

    static func roundCalories(_ value: Double) -> Int {
        Int((value / 10.0).rounded() * 10)
    }

    static func macroGrams(calories: Int, preference: MacroPreference) -> (protein: Int, carbs: Int, fat: Int) {
        let ratios = preference.ratios
        let protein = Int((Double(calories) * ratios.protein / 4.0).rounded())
        let carbs = Int((Double(calories) * ratios.carbs / 4.0).rounded())
        let fat = Int((Double(calories) * ratios.fat / 9.0).rounded())
        return (protein, carbs, fat)
    }

    static func calculate(_ input: Input) -> Output {
        if let manual = input.manualCalories, manual > 0 {
            let macros = macroGrams(calories: manual, preference: input.macroPreference)
            return Output(
                bmr: 0,
                tdee: 0,
                calories: manual,
                proteinGrams: macros.protein,
                carbGrams: macros.carbs,
                fatGrams: macros.fat,
                source: .manual,
                isEstimate: false
            )
        }

        if input.goalType == .trackOnly || input.formulaSex == .skipManual {
            let fallback = 2000
            let macros = macroGrams(calories: fallback, preference: input.macroPreference)
            return Output(
                bmr: 0,
                tdee: 0,
                calories: fallback,
                proteinGrams: macros.protein,
                carbGrams: macros.carbs,
                fatGrams: macros.fat,
                source: .manual,
                isEstimate: false
            )
        }

        let sex = input.formulaSex
        let bmrValue = bmr(
            weightKg: input.weightKg,
            heightCm: input.heightCm,
            age: input.age,
            formulaSex: sex
        ) ?? 0
        let tdee = bmrValue * input.activityMultiplier
        let adjusted = tdee * goalFactor(goalType: input.goalType, pace: input.pace)
        let calories = max(1200, roundCalories(adjusted))
        let macros = macroGrams(calories: calories, preference: input.macroPreference)

        return Output(
            bmr: bmrValue,
            tdee: tdee,
            calories: calories,
            proteinGrams: macros.protein,
            carbGrams: macros.carbs,
            fatGrams: macros.fat,
            source: .onboardingEstimate,
            isEstimate: true
        )
    }
}

enum UnitConversion {
    static func kilograms(fromPounds pounds: Double) -> Double { pounds * 0.45359237 }
    static func pounds(fromKilograms kg: Double) -> Double { kg / 0.45359237 }
    static func centimeters(fromInches inches: Double) -> Double { inches * 2.54 }
    static func centimeters(feet: Int, inches: Double) -> Double {
        centimeters(fromInches: Double(feet) * 12 + inches)
    }
    static func inches(fromCentimeters cm: Double) -> Double { cm / 2.54 }
}
