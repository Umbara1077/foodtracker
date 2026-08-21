import Testing
@testable import ProjectPlate
import Foundation

struct MicronutrientTests {
    @Test("Preference defaults to enabled")
    func preferenceDefault() {
        let suite = "plate.test.micros.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(MicronutrientPreference.isEnabled(defaults: defaults))
        MicronutrientPreference.setEnabled(false, defaults: defaults)
        #expect(!MicronutrientPreference.isEnabled(defaults: defaults))
    }

    @Test("Average present skips nil days")
    func averagePresent() {
        #expect(MicronutrientMath.averagePresent([nil, nil]) == nil)
        #expect(MicronutrientMath.averagePresent([10, nil, 20]) == 15)
    }

    @Test("Bundled catalog includes fiber on plant foods")
    func catalogHasFiber() {
        let beans = BundledNutritionCatalog.foods.first { $0.id == "usda.black_beans" }
        #expect(beans?.per100g.fiber == 8.7)
        #expect(beans?.per100g.sodiumMg == 1)
        let banana = BundledNutritionCatalog.foods.first { $0.id == "usda.banana" }
        #expect(banana?.per100g.sugar == 12)
    }

    @Test("NutritionResolver scales micros with portion")
    func scaleMicros() {
        let food = NutritionFood(
            id: "test.oats",
            source: .usdaShapedFixture,
            name: "Oats",
            brand: nil,
            serving: ServingDescriptor(label: "cup", grams: 100),
            per100g: NutrientSet(calories: 71, protein: 2.5, carbs: 12, fat: 1.5, fiber: 1.7, sugar: 0.3, sodiumMg: 4)
        )
        let half = NutritionResolver.nutrients(for: food, grams: 50)
        #expect(half.fiber == 0.8)
        #expect(half.sodiumMg == 2)
    }

    @Test("Weekly digest averages micronutrients from logged days")
    func weeklyDigestMicros() {
        let calendar = Calendar(identifier: .gregorian)
        let weekEnd = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!
        let mid = calendar.date(byAdding: .day, value: 3, to: weekStart)!
        let digest = ProgressMath.weeklyDigest(
            dailyTotals: [
                (
                    weekStart,
                    DayNutritionTotals(
                        nutrients: NutrientSet(calories: 1800, protein: 140, carbs: 0, fat: 0, fiber: 20, sugar: 40, sodiumMg: 2_000),
                        mealCount: 2
                    )
                ),
                (
                    mid,
                    DayNutritionTotals(
                        nutrients: NutrientSet(calories: 2200, protein: 160, carbs: 0, fat: 0, fiber: 30, sugar: nil, sodiumMg: 2_600),
                        mealCount: 3
                    )
                ),
            ],
            weightEntries: [],
            target: nil,
            weekStart: weekStart,
            weekEnd: weekEnd
        )
        #expect(digest.averageFiber == 25)
        #expect(digest.averageSugar == 40)
        #expect(digest.averageSodiumMg == 2_300)
    }

    @Test("Default micronutrient goals are soft public guidelines")
    func defaultGoals() {
        #expect(MicronutrientGoals.default.fiberGrams == 28)
        #expect(MicronutrientGoals.default.sugarGrams == 50)
        #expect(MicronutrientGoals.default.sodiumMg == 2_300)
    }
}
