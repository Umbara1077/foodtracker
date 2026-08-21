import Testing
@testable import ProjectPlate

struct TargetCalculatorTests {
    @Test("Male Mifflin–St Jeor BMR matches formula")
    func maleBMR() {
        // 80kg, 180cm, age 30, male: 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        let bmr = TargetCalculator.bmr(weightKg: 80, heightCm: 180, age: 30, formulaSex: .maleEquation)
        #expect(bmr == 1780)
    }

    @Test("Female Mifflin–St Jeor BMR matches formula")
    func femaleBMR() {
        // 65kg, 165cm, age 28, female: 10*65 + 6.25*165 - 5*28 - 161 = 650 + 1031.25 - 140 - 161 = 1380.25
        let bmr = TargetCalculator.bmr(weightKg: 65, heightCm: 165, age: 28, formulaSex: .femaleEquation)
        #expect(bmr == 1380.25)
    }

    @Test("Skip formula returns nil BMR")
    func skipBMR() {
        #expect(TargetCalculator.bmr(weightKg: 70, heightCm: 170, age: 25, formulaSex: .skipManual) == nil)
    }

    @Test("Maintain target rounds TDEE to nearest 10")
    func maintainRounding() {
        // BMR 1780 * 1.375 = 2447.5 → maintain → 2450
        let output = TargetCalculator.calculate(
            .init(
                weightKg: 80,
                heightCm: 180,
                age: 30,
                formulaSex: .maleEquation,
                activityMultiplier: ActivityLevel.lightlyActive.multiplier,
                goalType: .maintainWeight,
                pace: .moderate,
                macroPreference: .balanced,
                manualCalories: nil
            )
        )
        #expect(output.calories == 2450)
        #expect(output.source == .onboardingEstimate)
        #expect(output.isEstimate)
        // 25% P / 45% C / 30% F of 2450
        #expect(output.proteinGrams == Int((2450 * 0.25 / 4).rounded()))
        #expect(output.carbGrams == Int((2450 * 0.45 / 4).rounded()))
        #expect(output.fatGrams == Int((2450 * 0.30 / 9).rounded()))
    }

    @Test("Lose moderate applies 0.85 factor")
    func loseModerate() {
        let output = TargetCalculator.calculate(
            .init(
                weightKg: 80,
                heightCm: 180,
                age: 30,
                formulaSex: .maleEquation,
                activityMultiplier: 1.20,
                goalType: .loseWeight,
                pace: .moderate,
                macroPreference: .higherProtein,
                manualCalories: nil
            )
        )
        // BMR 1780 * 1.2 = 2136 * 0.85 = 1815.6 → 1820
        #expect(output.calories == 1820)
    }

    @Test("Gain faster applies 1.15 factor")
    func gainFaster() {
        let output = TargetCalculator.calculate(
            .init(
                weightKg: 80,
                heightCm: 180,
                age: 30,
                formulaSex: .maleEquation,
                activityMultiplier: 1.20,
                goalType: .gainWeight,
                pace: .faster,
                macroPreference: .balanced,
                manualCalories: nil
            )
        )
        // 2136 * 1.15 = 2456.4 → 2460
        #expect(output.calories == 2460)
    }

    @Test("Manual calories win over formula")
    func manualOverride() {
        let output = TargetCalculator.calculate(
            .init(
                weightKg: 80,
                heightCm: 180,
                age: 30,
                formulaSex: .maleEquation,
                activityMultiplier: 1.55,
                goalType: .maintainWeight,
                pace: .moderate,
                macroPreference: .balanced,
                manualCalories: 2100
            )
        )
        #expect(output.calories == 2100)
        #expect(output.source == .manual)
        #expect(!output.isEstimate)
    }

    @Test("Track-only defaults to 2000 without manual value")
    func trackOnlyDefault() {
        let output = TargetCalculator.calculate(
            .init(
                weightKg: 70,
                heightCm: 170,
                age: 25,
                formulaSex: .skipManual,
                activityMultiplier: 1.2,
                goalType: .trackOnly,
                pace: .moderate,
                macroPreference: .balanced,
                manualCalories: nil
            )
        )
        #expect(output.calories == 2000)
        #expect(output.source == .manual)
    }

    @Test("Unit conversion helpers")
    func units() {
        #expect(abs(UnitConversion.kilograms(fromPounds: 220) - 99.7903214) < 0.001)
        #expect(abs(UnitConversion.centimeters(feet: 5, inches: 10) - 177.8) < 0.001)
    }
}

struct ConfidenceAndNutrientTests {
    @Test("MealConfidence maps score bands from the product spec")
    func confidenceBands() {
        #expect(MealConfidence.from(score: 0.9) == .high)
        #expect(MealConfidence.from(score: 0.7) == .medium)
        #expect(MealConfidence.from(score: 0.4) == .low)
        #expect(MealConfidence.from(score: 0.85) == .high)
        #expect(MealConfidence.from(score: 0.65) == .medium)
    }

    @Test("NutrientSet addition is deterministic")
    func nutrientAddition() {
        let a = NutrientSet(calories: 100, protein: 10, carbs: 5, fat: 2)
        let b = NutrientSet(calories: 50, protein: 3, carbs: 4, fat: 1, fiber: 2)
        let sum = a + b
        #expect(sum.calories == 150)
        #expect(sum.protein == 13)
        #expect(sum.carbs == 9)
        #expect(sum.fat == 3)
        #expect(sum.fiber == 2)
    }
}

struct RepositorySmokeTests {
    @Test("In-memory profile and target repositories round-trip")
    func roundTrip() async throws {
        let profiles = InMemoryProfileRepository()
        let targets = InMemoryTargetRepository()

        var profile = UserProfile.blank
        profile.onboardingComplete = true
        profile.age = 30
        profile.heightCm = 180
        profile.currentWeightKg = 80
        try await profiles.saveProfile(profile)

        let snapshot = NutritionTargetSnapshot(
            calories: 2450,
            proteinGrams: 153,
            carbGrams: 276,
            fatGrams: 82,
            source: .onboardingEstimate
        )
        try await targets.saveTarget(snapshot)

        let loaded = try await profiles.loadProfile()
        #expect(loaded?.onboardingComplete == true)
        #expect(loaded?.age == 30)

        let current = try await targets.currentTarget(on: .now)
        #expect(current?.calories == 2450)
    }
}
