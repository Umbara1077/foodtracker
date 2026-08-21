import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 44 — History meal search")
struct Phase44HistorySearchTests {
    @Test("Empty query returns all meals")
    func emptyQuery() {
        let meals = [
            MealRecord(
                mealType: .breakfast,
                title: "Oats",
                nutrients: NutrientSet(calories: 300, protein: 10, carbs: 40, fat: 8),
                inputMethod: .quickAdd
            )
        ]
        #expect(MealSearch.filter(meals, query: "   ").count == 1)
        #expect(MealSearch.filter(meals, query: "").count == 1)
    }

    @Test("Matches title case-insensitively")
    func titleMatch() {
        let meals = [
            MealRecord(
                mealType: .lunch,
                title: "Chicken Bowl",
                nutrients: NutrientSet(calories: 500, protein: 40, carbs: 45, fat: 12),
                inputMethod: .photoScan
            ),
            MealRecord(
                mealType: .snack,
                title: "Apple",
                nutrients: NutrientSet(calories: 95, protein: 0, carbs: 25, fat: 0),
                inputMethod: .quickAdd
            ),
        ]
        let filtered = MealSearch.filter(meals, query: "chicken")
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Chicken Bowl")
    }

    @Test("Matches meal type and notes")
    func typeAndNotes() {
        let withNotes = MealRecord(
            mealType: .dinner,
            title: "Pasta",
            notes: "extra garlic",
            nutrients: NutrientSet(calories: 700, protein: 25, carbs: 90, fat: 20),
            inputMethod: .quickAdd
        )
        #expect(MealSearch.matches(withNotes, query: "Dinner"))
        #expect(MealSearch.matches(withNotes, query: "garlic"))
        #expect(!MealSearch.matches(withNotes, query: "pizza"))
    }
}
