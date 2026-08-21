import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 38 — Meal detail editor")
struct Phase38MealEditorTests {
    @Test("Saving an edited meal upserts by id and refreshes nutrients")
    func editKeepsIdentity() async throws {
        let original = MealRecord(
            mealType: .lunch,
            title: "Bowl",
            notes: "spicy",
            nutrients: NutrientSet(calories: 500, protein: 40, carbs: 45, fat: 12),
            inputMethod: .photoScan
        )
        let meals = InMemoryMealRepository(meals: [original])
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: nil),
            health: NoOpHealthSyncClient(),
            savedMeals: InMemorySavedMealRepository()
        )

        var edited = original
        edited.title = "Chicken bowl"
        edited.notes = nil
        edited.nutrients = NutrientSet(calories: 620, protein: 48, carbs: 55, fat: 18, fiber: 6)
        edited.mealType = .dinner
        try await diary.saveMeal(edited)

        let stored = try await meals.meal(id: original.id)
        #expect(stored?.title == "Chicken bowl")
        #expect(stored?.notes == nil)
        #expect(stored?.mealType == .dinner)
        #expect(stored?.nutrients.calories == 620)
        #expect(stored?.nutrients.fiber == 6)
        #expect(stored?.inputMethod == .photoScan)
        let allToday = try await meals.meals(on: .now, calendar: .current)
        #expect(allToday.count == 1)
    }

    @Test("Input method labels are human-readable")
    func inputMethodLabels() {
        #expect(MealInputMethod.photoScan.displayLabel == "Photo scan")
        #expect(MealInputMethod.duplicated.displayLabel == "Logged again")
        #expect(MealInputMethod.quickAdd.displayLabel == "Quick add")
    }
}
