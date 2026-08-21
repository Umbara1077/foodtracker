import Foundation

struct RecipeBuilderLine: Identifiable, Equatable, Sendable {
    var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBlank: Bool { trimmed.isEmpty }
}

enum RecipeBuilder {
    static func draft(
        title: String,
        servings: Double,
        lines: [RecipeBuilderLine]
    ) -> RecipeImportDraft {
        let ingredients = lines.map(\.trimmed).filter { !$0.isEmpty }
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return RecipeImportDraft(
            title: cleanedTitle.isEmpty ? "Homemade recipe" : cleanedTitle,
            sourceURL: nil,
            servings: max(servings, 1),
            ingredients: ingredients,
            nutrients: .zero,
            notes: "Built in Project Plate — review estimated nutrition."
        )
    }

    static func makeMeal(
        from draft: RecipeImportDraft,
        mealType: MealType,
        logServings: Double
    ) -> MealRecord {
        var meal = draft.makeMeal(mealType: mealType, logServings: logServings)
        meal.inputMethod = .recipeBuilder
        return meal
    }
}

struct RecipeBuilderEstimator: Sendable {
    var nutritionRepository: any NutritionRepository
    var maxIngredients: Int

    init(nutritionRepository: any NutritionRepository, maxIngredients: Int = 16) {
        self.nutritionRepository = nutritionRepository
        self.maxIngredients = maxIngredients
    }

    func estimate(draft: RecipeImportDraft) async throws -> RecipeImportDraft {
        var copy = draft
        let importer = RecipeURLImporter(
            fetcher: URLSessionRecipeFetcher(),
            nutritionRepository: nutritionRepository,
            maxIngredients: maxIngredients
        )
        copy.nutrients = try await importer.estimateNutrients(for: draft.ingredients)
        if copy.nutrients.calories <= 0 {
            copy.notes = [copy.notes, "Nutrition estimate unavailable — edit before relying on totals."]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        return copy
    }
}
