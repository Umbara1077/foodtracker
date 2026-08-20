import Foundation

/// Bundled USDA-shaped catalog for offline search (Phase 4).
/// Replace/extend with live FoodData Central in a later pass without changing UI.
enum BundledNutritionCatalog {
    static let foods: [NutritionFood] = [
        food("usda.chicken_breast_grilled", "Chicken breast, grilled", cal: 165, p: 31, c: 0, f: 3.6, serving: "breast", grams: 120),
        food("usda.chicken_thigh_roasted", "Chicken thigh, roasted", cal: 229, p: 25, c: 0, f: 15.5, serving: "thigh", grams: 100),
        food("usda.salmon_atlantic", "Salmon, Atlantic, cooked", cal: 208, p: 20, c: 0, f: 13, serving: "fillet", grams: 100),
        food("usda.egg_whole", "Egg, whole, cooked", cal: 155, p: 13, c: 1.1, f: 11, serving: "large egg", grams: 50),
        food("usda.egg_white", "Egg white, raw", cal: 52, p: 11, c: 0.7, f: 0.2, serving: "large", grams: 33),
        food("usda.greek_yogurt_plain", "Greek yogurt, plain, nonfat", cal: 59, p: 10, c: 3.6, f: 0.4, serving: "container", grams: 170),
        food("usda.milk_2pct", "Milk, 2% fat", cal: 50, p: 3.3, c: 4.8, f: 2, serving: "cup", grams: 244),
        food("usda.cheddar", "Cheddar cheese", cal: 403, p: 25, c: 1.3, f: 33, serving: "slice", grams: 28),
        food("usda.rice_white_cooked", "Rice, white, cooked", cal: 130, p: 2.7, c: 28, f: 0.3, serving: "cup", grams: 158),
        food("usda.rice_brown_cooked", "Rice, brown, cooked", cal: 123, p: 2.7, c: 25.6, f: 1, serving: "cup", grams: 195),
        food("usda.pasta_cooked", "Pasta, cooked", cal: 158, p: 5.8, c: 31, f: 0.9, serving: "cup", grams: 140),
        food("usda.oatmeal_cooked", "Oatmeal, cooked", cal: 71, p: 2.5, c: 12, f: 1.5, serving: "cup", grams: 234),
        food("usda.bread_wheat", "Bread, whole wheat", cal: 247, p: 13, c: 41, f: 3.4, serving: "slice", grams: 28),
        food("usda.bagel", "Bagel, plain", cal: 257, p: 10, c: 50, f: 1.7, serving: "bagel", grams: 95),
        food("usda.banana", "Banana, raw", cal: 89, p: 1.1, c: 23, f: 0.3, serving: "medium", grams: 118),
        food("usda.apple", "Apple, raw", cal: 52, p: 0.3, c: 14, f: 0.2, serving: "medium", grams: 182),
        food("usda.blueberries", "Blueberries, raw", cal: 57, p: 0.7, c: 14.5, f: 0.3, serving: "cup", grams: 148),
        food("usda.avocado", "Avocado, raw", cal: 160, p: 2, c: 8.5, f: 14.7, serving: "half", grams: 68),
        food("usda.broccoli", "Broccoli, cooked", cal: 35, p: 2.4, c: 7.2, f: 0.4, serving: "cup", grams: 156),
        food("usda.spinach_raw", "Spinach, raw", cal: 23, p: 2.9, c: 3.6, f: 0.4, serving: "cup", grams: 30),
        food("usda.potato_baked", "Potato, baked", cal: 93, p: 2.5, c: 21, f: 0.1, serving: "medium", grams: 173),
        food("usda.sweet_potato", "Sweet potato, baked", cal: 90, p: 2, c: 20.7, f: 0.2, serving: "medium", grams: 114),
        food("usda.black_beans", "Black beans, cooked", cal: 132, p: 8.9, c: 23.7, f: 0.5, serving: "cup", grams: 172),
        food("usda.lentils", "Lentils, cooked", cal: 116, p: 9, c: 20, f: 0.4, serving: "cup", grams: 198),
        food("usda.tofu_firm", "Tofu, firm", cal: 144, p: 17, c: 3.3, f: 9, serving: "1/2 cup", grams: 126),
        food("usda.almonds", "Almonds", cal: 579, p: 21, c: 22, f: 50, serving: "oz", grams: 28),
        food("usda.peanut_butter", "Peanut butter", cal: 588, p: 25, c: 20, f: 50, serving: "tbsp", grams: 16),
        food("usda.olive_oil", "Olive oil", cal: 884, p: 0, c: 0, f: 100, serving: "tbsp", grams: 14),
        food("usda.butter", "Butter", cal: 717, p: 0.9, c: 0.1, f: 81, serving: "tbsp", grams: 14),
        food("usda.granola", "Granola", cal: 471, p: 10, c: 64, f: 20, serving: "1/2 cup", grams: 61),
        food("usda.protein_powder_whey", "Whey protein powder", cal: 400, p: 80, c: 10, f: 5, serving: "scoop", grams: 30),
        food("usda.hummus", "Hummus", cal: 166, p: 8, c: 14, f: 10, serving: "2 tbsp", grams: 30),
        food("usda.tortilla_flour", "Flour tortilla", cal: 312, p: 8, c: 51, f: 8, serving: "tortilla", grams: 45),
        food("usda.ground_beef_90", "Ground beef, 90% lean, cooked", cal: 217, p: 26, c: 0, f: 12, serving: "3 oz", grams: 85),
        food("usda.turkey_breast", "Turkey breast, roasted", cal: 135, p: 30, c: 0, f: 1, serving: "3 oz", grams: 85),
        food("usda.tuna_canned", "Tuna, canned in water", cal: 86, p: 19, c: 0, f: 1, serving: "can drained", grams: 165),
        food("usda.quinoa_cooked", "Quinoa, cooked", cal: 120, p: 4.4, c: 21.3, f: 1.9, serving: "cup", grams: 185),
        food("usda.cottage_cheese", "Cottage cheese, lowfat", cal: 72, p: 12, c: 2.7, f: 1, serving: "1/2 cup", grams: 113),
        food("usda.orange", "Orange, raw", cal: 47, p: 0.9, c: 12, f: 0.1, serving: "medium", grams: 131),
        food("usda.strawberries", "Strawberries, raw", cal: 32, p: 0.7, c: 7.7, f: 0.3, serving: "cup", grams: 152),
    ]

    private static func food(
        _ id: String,
        _ name: String,
        cal: Double,
        p: Double,
        c: Double,
        f: Double,
        fiber: Double? = nil,
        serving: String,
        grams: Double
    ) -> NutritionFood {
        NutritionFood(
            id: id,
            source: .usdaShapedFixture,
            name: name,
            brand: nil,
            serving: ServingDescriptor(label: serving, grams: grams),
            per100g: NutrientSet(calories: cal, protein: p, carbs: c, fat: f, fiber: fiber)
        )
    }
}

actor LocalNutritionRepository: NutritionRepository {
    private let foods: [NutritionFood]
    private var cache: [String: [NutritionCandidate]] = [:]

    init(foods: [NutritionFood] = BundledNutritionCatalog.foods) {
        self.foods = foods
    }

    func search(_ query: NutritionSearchQuery) async throws -> [NutritionCandidate] {
        let key = [
            query.text.lowercased(),
            query.brand?.lowercased() ?? "",
            query.preparation?.lowercased() ?? "",
        ].joined(separator: "|")

        if let cached = cache[key] {
            return cached
        }

        // Light debounce-friendly yield for UI responsiveness.
        try await Task.sleep(nanoseconds: 50_000_000)
        let ranked = NutritionResolver.rank(candidates: foods, query: query)
        cache[key] = ranked
        return ranked
    }

    func details(id: NutritionFoodID) async throws -> NutritionFood {
        guard let food = foods.first(where: { $0.id == id.rawValue }) else {
            throw NutritionRepositoryError.notFound
        }
        return food
    }
}

enum NutritionRepositoryError: Error, LocalizedError, Sendable {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "Food not found in the nutrition catalog."
        }
    }
}
