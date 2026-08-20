import Foundation

/// Curated chain menu estimates for offline restaurant matching (PRODUCT_SPEC §34.1).
/// Values are approximate fixture data — not scraped and not official restaurant APIs.
enum BundledRestaurantCatalog {
    static let foods: [NutritionFood] = [
        // Chipotle-style
        restaurant(
            "rest.chipotle.chicken",
            "Chicken",
            brand: "Chipotle",
            cal: 180, p: 32, c: 0, f: 7,
            serving: "serving", grams: 113
        ),
        restaurant(
            "rest.chipotle.steak",
            "Steak",
            brand: "Chipotle",
            cal: 150, p: 21, c: 1, f: 6,
            serving: "serving", grams: 113
        ),
        restaurant(
            "rest.chipotle.carnitas",
            "Carnitas",
            brand: "Chipotle",
            cal: 210, p: 23, c: 0, f: 12,
            serving: "serving", grams: 113
        ),
        restaurant(
            "rest.chipotle.cilantro_lime_rice",
            "Cilantro-lime rice",
            brand: "Chipotle",
            cal: 210, p: 4, c: 40, f: 4,
            serving: "serving", grams: 113
        ),
        restaurant(
            "rest.chipotle.black_beans",
            "Black beans",
            brand: "Chipotle",
            cal: 130, p: 8, c: 22, f: 1.5,
            serving: "serving", grams: 113
        ),
        restaurant(
            "rest.chipotle.guacamole",
            "Guacamole",
            brand: "Chipotle",
            cal: 230, p: 2, c: 8, f: 22,
            serving: "serving", grams: 113
        ),
        restaurant(
            "rest.chipotle.burrito_bowl",
            "Burrito bowl",
            brand: "Chipotle",
            cal: 190, p: 12, c: 20, f: 7,
            serving: "assembled bowl estimate / 100g", grams: 100
        ),

        // Starbucks-style
        restaurant(
            "rest.starbucks.latte_grande",
            "Caffe latte",
            brand: "Starbucks",
            cal: 48, p: 3.2, c: 4.8, f: 1.9,
            serving: "grande ~470ml as per-100g proxy", grams: 100
        ),
        restaurant(
            "rest.starbucks.egg_bites",
            "Egg bites, bacon & gruyere",
            brand: "Starbucks",
            cal: 245, p: 15, c: 9, f: 17,
            serving: "2 bites", grams: 130
        ),
        restaurant(
            "rest.starbucks.oatmeal",
            "Classic oatmeal",
            brand: "Starbucks",
            cal: 100, p: 3.5, c: 18, f: 2,
            serving: "bowl", grams: 225
        ),

        // McDonald's-style
        restaurant(
            "rest.mcdonalds.hamburger",
            "Hamburger",
            brand: "McDonald's",
            cal: 250, p: 12, c: 31, f: 9,
            serving: "sandwich", grams: 100
        ),
        restaurant(
            "rest.mcdonalds.cheeseburger",
            "Cheeseburger",
            brand: "McDonald's",
            cal: 270, p: 13, c: 32, f: 11,
            serving: "sandwich", grams: 110
        ),
        restaurant(
            "rest.mcdonalds.fries_medium",
            "French fries",
            brand: "McDonald's",
            cal: 310, p: 4, c: 40, f: 15,
            serving: "medium", grams: 110
        ),
        restaurant(
            "rest.mcdonalds.nuggets",
            "Chicken McNuggets",
            brand: "McDonald's",
            cal: 290, p: 15, c: 18, f: 18,
            serving: "4 piece", grams: 64
        ),

        // Sweetgreen / salad-bowl style
        restaurant(
            "rest.sweetgreen.harvest_bowl",
            "Harvest bowl",
            brand: "Sweetgreen",
            cal: 140, p: 7, c: 16, f: 6,
            serving: "bowl estimate / 100g", grams: 100
        ),
        restaurant(
            "rest.sweetgreen.chicken",
            "Roasted chicken",
            brand: "Sweetgreen",
            cal: 160, p: 28, c: 0, f: 5,
            serving: "serving", grams: 100
        ),

        // Panera-style
        restaurant(
            "rest.panera.broccoli_cheddar",
            "Broccoli cheddar soup",
            brand: "Panera",
            cal: 95, p: 4, c: 8, f: 6,
            serving: "cup estimate / 100g", grams: 100
        ),
        restaurant(
            "rest.panera.turkey_sandwich",
            "Turkey sandwich",
            brand: "Panera",
            cal: 180, p: 14, c: 20, f: 5,
            serving: "half estimate / 100g", grams: 100
        ),
    ]

    private static func restaurant(
        _ id: String,
        _ name: String,
        brand: String,
        cal: Double,
        p: Double,
        c: Double,
        f: Double,
        serving: String,
        grams: Double
    ) -> NutritionFood {
        NutritionFood(
            id: id,
            source: .restaurantCatalog,
            name: name,
            brand: brand,
            serving: ServingDescriptor(label: serving, grams: grams),
            per100g: NutrientSet(calories: cal, protein: p, carbs: c, fat: f)
        )
    }
}

/// Normalizes chain / brand strings so “mcd”, “McDonalds”, and “McDonald's” match.
enum RestaurantBrandNormalizer {
    /// Canonical brand → accepted aliases (lowercase).
    static let aliases: [String: Set<String>] = [
        "chipotle": ["chipotle", "chipotle mexican grill"],
        "starbucks": ["starbucks", "sbux"],
        "mcdonald's": ["mcdonald's", "mcdonalds", "mcd", "mickie d's", "mickey d's"],
        "sweetgreen": ["sweetgreen", "sweet green"],
        "panera": ["panera", "panera bread"],
    ]

    static func canonicalBrand(from raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !cleaned.isEmpty else { return nil }
        for (canonical, names) in aliases {
            if names.contains(cleaned) || names.contains(where: { cleaned.contains($0) || $0.contains(cleaned) }) {
                return canonical
            }
        }
        return cleaned
    }

    static func brandsMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let a = canonicalBrand(from: lhs), let b = canonicalBrand(from: rhs) else { return false }
        return a == b
    }

    /// True when query brand looks like a known restaurant chain (or any non-empty brand hint).
    static func isRestaurantContext(_ brandOrRestaurant: String?) -> Bool {
        guard let brand = canonicalBrand(from: brandOrRestaurant) else { return false }
        return aliases.keys.contains(brand) || brand.count >= 3
    }
}

/// Prefer restaurant-catalog hits when vision supplies a brand/restaurant hint.
enum RestaurantMealMatcher {
    static func preferredCandidate(
        from candidates: [NutritionCandidate],
        brandOrRestaurant: String?
    ) -> NutritionCandidate? {
        guard RestaurantBrandNormalizer.isRestaurantContext(brandOrRestaurant) else {
            return candidates.first
        }
        let restaurantHits = candidates.filter {
            $0.food.source == .restaurantCatalog
                && RestaurantBrandNormalizer.brandsMatch($0.food.brand, brandOrRestaurant)
        }
        if let bestRestaurant = restaurantHits.first {
            return bestRestaurant
        }
        // Brand-matched generic foods still beat unrelated catalog hits.
        let brandHits = candidates.filter {
            RestaurantBrandNormalizer.brandsMatch($0.food.brand, brandOrRestaurant)
        }
        return brandHits.first ?? candidates.first
    }

    static func searchQuery(for item: VisionFoodItem, locale: Locale) -> NutritionSearchQuery {
        NutritionSearchQuery(
            text: item.canonicalQuery,
            brand: item.brandOrRestaurant,
            preparation: item.preparation,
            locale: locale
        )
    }
}

/// Pulls restaurant brand hints from correction titles/notes for ranking preference.
enum RestaurantBrandHistory {
    static func brands(from corrections: [MealCorrectionFeedback]) -> [String] {
        var found: [String] = []
        for correction in corrections {
            let haystack = "\(correction.mealTitle) \(correction.notes)".lowercased()
            for brand in RestaurantBrandNormalizer.aliases.keys where haystack.contains(brand) {
                if !found.contains(brand) {
                    found.append(brand)
                }
            }
        }
        return found
    }
}
