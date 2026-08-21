import Testing
@testable import ProjectPlate
import Foundation

struct NutritionRepositoryTests {
    @Test("Exact name ranks above partial match")
    func rankingPrefersExact() {
        let foods = [
            NutritionFood(
                id: "a",
                source: .usdaShapedFixture,
                name: "Chicken breast, grilled",
                brand: nil,
                serving: ServingDescriptor(label: "breast", grams: 120),
                per100g: NutrientSet(calories: 165, protein: 31, carbs: 0, fat: 3.6)
            ),
            NutritionFood(
                id: "b",
                source: .usdaShapedFixture,
                name: "Chicken thigh, roasted",
                brand: nil,
                serving: ServingDescriptor(label: "thigh", grams: 100),
                per100g: NutrientSet(calories: 229, protein: 25, carbs: 0, fat: 15.5)
            ),
        ]
        let ranked = NutritionResolver.rank(
            candidates: foods,
            query: NutritionSearchQuery(
                text: "Chicken breast, grilled",
                brand: nil,
                preparation: "grilled",
                locale: .current
            )
        )
        #expect(ranked.first?.food.id == "a")
        #expect((ranked.first?.score ?? 0) > (ranked.last?.score ?? 0))
    }

    @Test("Preparation boosts matching foods")
    func preparationBoost() {
        let foods = [
            NutritionFood(
                id: "grilled",
                source: .usdaShapedFixture,
                name: "Chicken breast, grilled",
                brand: nil,
                serving: nil,
                per100g: NutrientSet(calories: 165, protein: 31, carbs: 0, fat: 3.6)
            ),
            NutritionFood(
                id: "raw",
                source: .usdaShapedFixture,
                name: "Chicken breast, raw",
                brand: nil,
                serving: nil,
                per100g: NutrientSet(calories: 120, protein: 22, carbs: 0, fat: 2.6)
            ),
        ]
        let ranked = NutritionResolver.rank(
            candidates: foods,
            query: NutritionSearchQuery(
                text: "chicken breast",
                brand: nil,
                preparation: "grilled",
                locale: .current
            )
        )
        #expect(ranked.first?.food.id == "grilled")
    }

    @Test("Local catalog search finds chicken and rice")
    func localSearch() async throws {
        let repo = LocalNutritionRepository()
        let chicken = try await repo.search(
            NutritionSearchQuery(text: "chicken", brand: nil, preparation: nil, locale: .current)
        )
        #expect(!chicken.isEmpty)
        #expect(chicken.contains(where: { $0.food.name.lowercased().contains("chicken") }))

        let rice = try await repo.search(
            NutritionSearchQuery(text: "white rice", brand: nil, preparation: "cooked", locale: .current)
        )
        #expect(rice.first?.food.name.lowercased().contains("rice") == true)
    }

    @Test("Nutrient scaling is linear from per-100g")
    func nutrientScale() {
        let food = NutritionFood(
            id: "x",
            source: .usdaShapedFixture,
            name: "Test",
            brand: nil,
            serving: nil,
            per100g: NutrientSet(calories: 200, protein: 10, carbs: 20, fat: 5)
        )
        let half = NutritionResolver.nutrients(for: food, grams: 50)
        #expect(half.calories == 100)
        #expect(half.protein == 5)
    }

    @Test("Details lookup returns catalog food")
    func details() async throws {
        let repo = LocalNutritionRepository()
        let food = try await repo.details(id: NutritionFoodID(rawValue: "usda.avocado"))
        #expect(food.name.lowercased().contains("avocado"))
    }
}
