import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 23 — Recipe URL import")
struct RecipeURLImportTests {
    private let sampleHTML = """
    <html><head><script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Recipe",
      "name": "Simple Chicken Bowl",
      "recipeYield": "2 servings",
      "recipeIngredient": [
        "1 cup cooked white rice",
        "4 oz grilled chicken breast",
        "1/2 avocado",
        "1 tbsp olive oil"
      ]
    }
    </script></head><body></body></html>
    """

    @Test("JSON-LD recipe extracts title ingredients and servings")
    func jsonLDParse() {
        let draft = RecipeHTMLParser.parse(
            html: sampleHTML,
            sourceURL: URL(string: "https://example.com/chicken-bowl")
        )
        #expect(draft?.title == "Simple Chicken Bowl")
        #expect(draft?.servings == 2)
        #expect(draft?.ingredients.count == 4)
        #expect(draft?.ingredients.contains(where: { $0.lowercased().contains("chicken") }) == true)
    }

    @Test("Ingredient estimator maps cups and ounces")
    func estimator() {
        #expect(abs(RecipeIngredientEstimator.estimatedGrams(for: "1 cup rice") - 120) < 0.1)
        #expect(abs(RecipeIngredientEstimator.estimatedGrams(for: "4 oz chicken") - 112) < 0.1)
        #expect(RecipeIngredientEstimator.searchQuery(for: "1 cup cooked white rice").contains("rice"))
    }

    @Test("Importer estimates nutrition from fixture HTML without network")
    func importerOffline() async throws {
        struct StubFetcher: RecipeURLFetching {
            let html: String
            func html(from url: URL) async throws -> String { html }
        }
        let importer = RecipeURLImporter(
            fetcher: StubFetcher(html: sampleHTML),
            nutritionRepository: LocalNutritionRepository(openFoodFacts: nil)
        )
        let draft = try await importer.importRecipe(from: "https://example.com/recipe")
        #expect(draft.title == "Simple Chicken Bowl")
        #expect(draft.nutrients.calories > 100)
        let meal = draft.makeMeal(logServings: 1)
        #expect(meal.inputMethod == .recipeURL)
        #expect(meal.nutrients.calories > 0)
        #expect(meal.nutrients.calories < draft.nutrients.calories)
    }

    @Test("Normalized URL accepts host without scheme")
    func normalizeURL() {
        #expect(RecipeURLImporter.normalizedURL(from: "example.com/food")?.host == "example.com")
        #expect(RecipeURLImporter.normalizedURL(from: "https://example.com/x")?.scheme == "https")
        #expect(RecipeURLImporter.normalizedURL(from: "") == nil)
    }

    @Test("Heuristic parse finds ingredient block")
    func heuristic() {
        let html = """
        <html><body>
        <h1>Oatmeal Bowl</h1>
        <h2>Ingredients</h2>
        <ul>
          <li>1 cup oatmeal</li>
          <li>1 banana</li>
          <li>2 tbsp peanut butter</li>
        </ul>
        <h2>Directions</h2>
        <p>Cook and serve.</p>
        </body></html>
        """
        let draft = RecipeHTMLParser.parseHeuristic(html: html, sourceURL: nil)
        #expect(draft != nil)
        #expect((draft?.ingredients.count ?? 0) >= 2)
    }
}
