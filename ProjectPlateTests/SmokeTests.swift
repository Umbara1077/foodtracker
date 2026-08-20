import Testing
@testable import ProjectPlate

struct SmokeTests {
    @Test("MealConfidence maps score bands from the product spec")
    func confidenceBands() {
        #expect(MealConfidence.from(score: 0.9) == .high)
        #expect(MealConfidence.from(score: 0.7) == .medium)
        #expect(MealConfidence.from(score: 0.4) == .low)
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

    @Test("In-memory meal repository returns empty diary for Phase 0")
    func emptyDiary() async throws {
        let repo = InMemoryMealRepository()
        let meals = try await repo.meals(on: .now, calendar: .current)
        #expect(meals.isEmpty)
    }
}
