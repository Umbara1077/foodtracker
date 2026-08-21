import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 42 — Undo meal delete")
struct Phase42UndoDeleteTests {
    @Test("Banner message quotes the meal title")
    func bannerCopy() {
        let meal = MealRecord(
            mealType: .lunch,
            title: "Chicken bowl",
            nutrients: NutrientSet(calories: 500, protein: 40, carbs: 40, fat: 15),
            inputMethod: .quickAdd
        )
        #expect(MealDeleteUndo.bannerMessage(for: meal) == "Deleted \"Chicken bowl\"")
    }

    @Test("Delete then save restores the same meal id")
    func undoRestoresIdentity() async throws {
        let meal = MealRecord(
            mealType: .breakfast,
            title: "Oats",
            nutrients: NutrientSet(calories: 350, protein: 12, carbs: 55, fat: 8),
            inputMethod: .quickAdd
        )
        let meals = InMemoryMealRepository(meals: [meal])
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: nil),
            health: NoOpHealthSyncClient(),
            savedMeals: InMemorySavedMealRepository()
        )

        try await diary.deleteMeal(meal)
        #expect(try await meals.meal(id: meal.id) == nil)

        try await diary.saveMeal(meal)
        let restored = try await meals.meal(id: meal.id)
        #expect(restored?.id == meal.id)
        #expect(restored?.title == "Oats")
        #expect(restored?.nutrients.calories == 350)
    }
}
