import Foundation

enum NutritionSource: String, Codable, Sendable {
    case usdaShapedFixture
    case usdaFoodDataCentral
    case openFoodFacts
    case userCustom
    case aiEstimate
    case nutritionLabelOCR
    case restaurantCatalog
}

struct NutritionFoodID: Hashable, Codable, Sendable {
    var rawValue: String
}

struct ServingDescriptor: Codable, Sendable, Equatable {
    var label: String
    var grams: Double
}

struct NutritionFood: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var source: NutritionSource
    var name: String
    var brand: String?
    var serving: ServingDescriptor?
    var per100g: NutrientSet

    var nutritionFoodID: NutritionFoodID { NutritionFoodID(rawValue: id) }
}

struct NutritionCandidate: Identifiable, Sendable, Equatable {
    var id: String { food.id }
    var food: NutritionFood
    var score: Double
}

struct NutritionSearchQuery: Sendable {
    var text: String
    var brand: String?
    var preparation: String?
    var locale: Locale
}

protocol NutritionRepository: Sendable {
    func search(_ query: NutritionSearchQuery) async throws -> [NutritionCandidate]
    func details(id: NutritionFoodID) async throws -> NutritionFood
    /// Lookup by UPC/EAN. Returns nil when unknown — never invent nutrition from digits alone.
    func lookupBarcode(_ code: String) async throws -> NutritionFood?
    /// Optional restaurant brand preference from user corrections (no-op by default).
    func setPreferredBrandHistory(_ brands: [String]) async
}

extension NutritionRepository {
    func setPreferredBrandHistory(_ brands: [String]) async {}
}

enum NutritionResolver {
    /// Spec §34.5 ranking weights (+ restaurant brand alias boost).
    static func rank(
        candidates: [NutritionFood],
        query: NutritionSearchQuery,
        preferredBrandHistory: [String] = []
    ) -> [NutritionCandidate] {
        let q = query.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let history = Set(preferredBrandHistory.compactMap { RestaurantBrandNormalizer.canonicalBrand(from: $0) })

        return candidates.map { food in
            let name = food.name.lowercased()
            let brand = (food.brand ?? "").lowercased()
            var score = 0.0

            // lexical similarity 0.35
            if name == q {
                score += 0.35
            } else if name.hasPrefix(q) {
                score += 0.28
            } else if name.contains(q) || q.split(separator: " ").allSatisfy({ name.contains($0) }) {
                score += 0.18
            } else {
                score += tokenOverlap(q, name) * 0.35
            }

            // prep match 0.20
            if let prep = query.preparation?.lowercased(), !prep.isEmpty {
                if name.contains(prep) { score += 0.20 }
            }

            // brand match 0.20 (+ alias-aware restaurant boost)
            if let brandQuery = query.brand, !brandQuery.isEmpty {
                if RestaurantBrandNormalizer.brandsMatch(food.brand, brandQuery) {
                    score += 0.20
                    if food.source == .restaurantCatalog {
                        score += 0.08
                    }
                } else if brand.contains(brandQuery.lowercased()) || brandQuery.lowercased().contains(brand) {
                    score += 0.12
                }
            }

            // source confidence 0.15
            switch food.source {
            case .usdaFoodDataCentral, .usdaShapedFixture: score += 0.15
            case .restaurantCatalog:
                // Strong when brand matches; otherwise slightly below USDA generics.
                if RestaurantBrandNormalizer.brandsMatch(food.brand, query.brand) {
                    score += 0.16
                } else {
                    score += 0.06
                }
            case .openFoodFacts: score += 0.10
            case .userCustom: score += 0.08
            case .aiEstimate: score += 0.03
            case .nutritionLabelOCR: score += 0.05
            }

            // user-history preference 0.10 (correction / prior restaurant brands)
            if let canonical = RestaurantBrandNormalizer.canonicalBrand(from: food.brand),
               history.contains(canonical) {
                score += 0.10
            }

            // slight boost for having a default serving
            if food.serving != nil { score += 0.02 }

            return NutritionCandidate(food: food, score: min(score, 1.0))
        }
        .filter { $0.score > 0.05 }
        .sorted { $0.score > $1.score }
    }

    private static func tokenOverlap(_ query: String, _ name: String) -> Double {
        let qTokens = Set(query.split(separator: " ").map(String.init))
        let nTokens = Set(name.split(separator: " ").map(String.init))
        guard !qTokens.isEmpty else { return 0 }
        let overlap = qTokens.intersection(nTokens).count
        return Double(overlap) / Double(qTokens.count)
    }

    static func nutrients(for food: NutritionFood, grams: Double) -> NutrientSet {
        let factor = grams / 100.0
        return NutrientSet(
            calories: (food.per100g.calories * factor).rounded(),
            protein: (food.per100g.protein * factor * 10).rounded() / 10,
            carbs: (food.per100g.carbs * factor * 10).rounded() / 10,
            fat: (food.per100g.fat * factor * 10).rounded() / 10,
            fiber: food.per100g.fiber.map { ($0 * factor * 10).rounded() / 10 },
            sugar: food.per100g.sugar.map { ($0 * factor * 10).rounded() / 10 },
            sodiumMg: food.per100g.sodiumMg.map { ($0 * factor).rounded() }
        )
    }
}
