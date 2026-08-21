import Testing
@testable import ProjectPlate
import Foundation

struct QuickAddMathTests {
    @Test("Macros-only quick add derives Atwater calories")
    func macrosOnly() {
        let result = QuickAddMath.resolve(caloriesText: nil, protein: 30, carbs: 40, fat: 10)
        // 30*4 + 40*4 + 10*9 = 120 + 160 + 90 = 370
        #expect(result.calories == 370)
        #expect(result.warning == nil)
    }

    @Test("Entered calories kept when macros diverge")
    func calorieOverrideWarning() {
        let result = QuickAddMath.resolve(caloriesText: "500", protein: 30, carbs: 40, fat: 10)
        #expect(result.calories == 500)
        #expect(result.warning != nil)
    }

    @Test("Empty input returns zero with error hint")
    func empty() {
        let result = QuickAddMath.resolve(caloriesText: "", protein: nil, carbs: nil, fat: nil)
        #expect(result.calories == 0)
        #expect(result.warning != nil)
    }
}

struct DayBoundaryTests {
    @Test("Day boundary containment uses local calendar")
    func containment() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))!
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        let nextMorning = calendar.date(byAdding: .day, value: 1, to: morning)!
        #expect(DayBoundary.contains(morning, day: day, calendar: calendar))
        #expect(!DayBoundary.contains(nextMorning, day: day, calendar: calendar))
    }
}

struct MealRepositoryTests {
    @Test("In-memory meal repository totals and delete")
    func totalsAndDelete() async throws {
        let repo = InMemoryMealRepository()
        let meal = MealRecord(
            mealType: .breakfast,
            title: "Eggs",
            nutrients: NutrientSet(calories: 220, protein: 18, carbs: 2, fat: 14),
            inputMethod: .quickAdd
        )
        try await repo.save(meal)
        let totals = try await repo.totals(on: .now, calendar: .current)
        #expect(totals.mealCount == 1)
        #expect(totals.nutrients.calories == 220)

        try await repo.delete(id: meal.id)
        let after = try await repo.totals(on: .now, calendar: .current)
        #expect(after.mealCount == 0)
    }

    @Test("Duplicate path creates a new id")
    func duplicateIdentity() async throws {
        let repo = InMemoryMealRepository()
        let original = MealRecord(
            mealType: .lunch,
            title: "Bowl",
            nutrients: NutrientSet(calories: 600, protein: 40, carbs: 50, fat: 20),
            inputMethod: .quickAdd
        )
        try await repo.save(original)
        var copy = original
        copy.id = UUID()
        copy.inputMethod = .duplicated
        try await repo.save(copy)
        let meals = try await repo.meals(on: .now, calendar: .current)
        #expect(meals.count == 2)
    }
}
