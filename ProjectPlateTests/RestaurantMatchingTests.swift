import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 21 — Restaurant matching")
struct RestaurantMatchingTests {
    @Test("Brand aliases normalize McDonald's variants")
    func brandAliases() {
        #expect(RestaurantBrandNormalizer.canonicalBrand(from: "mcd") == "mcdonald's")
        #expect(RestaurantBrandNormalizer.canonicalBrand(from: "McDonalds") == "mcdonald's")
        #expect(RestaurantBrandNormalizer.brandsMatch("Chipotle Mexican Grill", "chipotle"))
        #expect(!RestaurantBrandNormalizer.brandsMatch("Chipotle", "Starbucks"))
    }

    @Test("Chipotle chicken outranks generic USDA chicken when brand is set")
    func restaurantBeatsGeneric() {
        let foods = BundledNutritionCatalog.foods + BundledRestaurantCatalog.foods
        let ranked = NutritionResolver.rank(
            candidates: foods,
            query: NutritionSearchQuery(
                text: "chicken",
                brand: "Chipotle",
                preparation: nil,
                locale: .current
            )
        )
        #expect(ranked.first?.food.source == .restaurantCatalog)
        #expect(ranked.first?.food.brand == "Chipotle")
        #expect(ranked.first?.food.id == "rest.chipotle.chicken")
    }

    @Test("Preferred candidate picks restaurant catalog over higher generic when brand matches")
    func preferredCandidate() {
        let generic = NutritionCandidate(
            food: NutritionFood(
                id: "usda.chicken",
                source: .usdaShapedFixture,
                name: "Chicken breast, grilled",
                brand: nil,
                serving: nil,
                per100g: NutrientSet(calories: 165, protein: 31, carbs: 0, fat: 3.6)
            ),
            score: 0.9
        )
        let restaurant = NutritionCandidate(
            food: NutritionFood(
                id: "rest.chipotle.chicken",
                source: .restaurantCatalog,
                name: "Chicken",
                brand: "Chipotle",
                serving: nil,
                per100g: NutrientSet(calories: 180, protein: 32, carbs: 0, fat: 7)
            ),
            score: 0.7
        )
        let preferred = RestaurantMealMatcher.preferredCandidate(
            from: [generic, restaurant],
            brandOrRestaurant: "Chipotle"
        )
        #expect(preferred?.food.id == "rest.chipotle.chicken")
    }

    @Test("User correction history boosts matching restaurant brand")
    func historyBoost() {
        let foods = [
            NutritionFood(
                id: "rest.starbucks.oatmeal",
                source: .restaurantCatalog,
                name: "Classic oatmeal",
                brand: "Starbucks",
                serving: nil,
                per100g: NutrientSet(calories: 100, protein: 3.5, carbs: 18, fat: 2)
            ),
            NutritionFood(
                id: "usda.oatmeal_cooked",
                source: .usdaShapedFixture,
                name: "Oatmeal, cooked",
                brand: nil,
                serving: nil,
                per100g: NutrientSet(calories: 71, protein: 2.5, carbs: 12, fat: 1.5)
            ),
        ]
        let query = NutritionSearchQuery(text: "oatmeal", brand: nil, preparation: nil, locale: .current)
        let without = NutritionResolver.rank(candidates: foods, query: query)
        let withHistory = NutritionResolver.rank(
            candidates: foods,
            query: query,
            preferredBrandHistory: ["starbucks"]
        )
        let baseScore = without.first(where: { $0.food.id == "rest.starbucks.oatmeal" })?.score ?? 0
        let boosted = withHistory.first(where: { $0.food.id == "rest.starbucks.oatmeal" })?.score ?? 0
        #expect(boosted > baseScore)
        // History is a soft preference (0.10); stronger lexical USDA matches can still rank first.
        #expect(withHistory.contains(where: { $0.food.id == "rest.starbucks.oatmeal" }))
    }

    @Test("Correction notes extract restaurant brands")
    func historyFromCorrections() {
        let feedback = MealCorrectionFeedback(
            mealTitle: "Chipotle lunch",
            estimatedCalories: 800,
            notes: "Actually Starbucks oatmeal earlier"
        )
        let brands = RestaurantBrandHistory.brands(from: [feedback])
        #expect(brands.contains("chipotle"))
        #expect(brands.contains("starbucks"))
    }

    @Test("Chipotle fixture resolves to restaurant catalog items")
    func chipotleAnalysis() async throws {
        let service = MealAnalysisService(
            visionProvider: MockMealVisionProvider(fixture: .chipotleBowl, delayNanoseconds: 0),
            nutritionRepository: LocalNutritionRepository(openFoodFacts: nil)
        )
        let draft = try await service.analyze(
            imageData: Data(repeating: 1, count: 8),
            context: .default,
            onStage: { _ in }
        )
        #expect(draft.items.count == 4)
        #expect(draft.items.contains(where: { $0.nutritionSourceLabel.contains("Restaurant") }))
        #expect(draft.items.contains(where: { $0.displayName.lowercased().contains("chicken") }))
        #expect(draft.items.contains(where: { $0.displayName.lowercased().contains("guacamole") }))
    }

    @Test("Local search with McDonald's brand finds fries")
    func mcdonaldsSearch() async throws {
        let repo = LocalNutritionRepository(openFoodFacts: nil)
        let results = try await repo.search(
            NutritionSearchQuery(text: "fries", brand: "mcd", preparation: nil, locale: .current)
        )
        #expect(results.first?.food.brand == "McDonald's")
        #expect(results.first?.food.source == .restaurantCatalog)
    }
}
