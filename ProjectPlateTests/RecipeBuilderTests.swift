import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 24 — Recipe builder")
struct RecipeBuilderTests {
    @Test("Draft collects non-blank ingredient lines")
    func draftFromLines() {
        let lines = [
            RecipeBuilderLine(text: "1 cup rice"),
            RecipeBuilderLine(text: "  "),
            RecipeBuilderLine(text: "4 oz chicken"),
        ]
        let draft = RecipeBuilder.draft(title: "Bowl", servings: 2, lines: lines)
        #expect(draft.title == "Bowl")
        #expect(draft.servings == 2)
        #expect(draft.ingredients == ["1 cup rice", "4 oz chicken"])
    }

    @Test("Empty title falls back to homemade recipe")
    func defaultTitle() {
        let draft = RecipeBuilder.draft(
            title: "  ",
            servings: 1,
            lines: [RecipeBuilderLine(text: "1 banana")]
        )
        #expect(draft.title == "Homemade recipe")
    }

    @Test("Estimator fills nutrients from catalog")
    func estimate() async throws {
        let draft = RecipeBuilder.draft(
            title: "Rice bowl",
            servings: 2,
            lines: [
                RecipeBuilderLine(text: "1 cup cooked white rice"),
                RecipeBuilderLine(text: "4 oz grilled chicken breast"),
            ]
        )
        let estimator = RecipeBuilderEstimator(
            nutritionRepository: LocalNutritionRepository(openFoodFacts: nil)
        )
        let estimated = try await estimator.estimate(draft: draft)
        #expect(estimated.nutrients.calories > 50)
        let meal = RecipeBuilder.makeMeal(from: estimated, mealType: .lunch, logServings: 1)
        #expect(meal.inputMethod == .recipeBuilder)
        #expect(meal.nutrients.calories > 0)
        #expect(meal.nutrients.calories <= estimated.nutrients.calories)
    }
}
