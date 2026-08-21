import Foundation

/// Aggregated meal template for frequent re-logging (PRODUCT_SPEC §73).
struct SavedMealTemplate: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    /// Stable key from normalized title + rounded macros.
    var fingerprint: String
    var title: String
    var mealType: MealType
    var nutrients: NutrientSet
    var useCount: Int
    var lastUsedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fingerprint: String,
        title: String,
        mealType: MealType,
        nutrients: NutrientSet,
        useCount: Int = 1,
        lastUsedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.title = title
        self.mealType = mealType
        self.nutrients = nutrients
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }

    /// Builds a diary meal for “log again” without AI cost.
    func makeMeal(eatenAt: Date = .now) -> MealRecord {
        MealRecord(
            eatenAt: eatenAt,
            mealType: MealType.inferred(from: eatenAt),
            title: title,
            nutrients: nutrients,
            inputMethod: .duplicated
        )
    }

    static func fingerprint(for meal: MealRecord) -> String {
        fingerprint(title: meal.title, nutrients: meal.nutrients)
    }

    static func fingerprint(title: String, nutrients: NutrientSet) -> String {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let cal = Int((nutrients.calories / 10).rounded() * 10)
        let p = Int(nutrients.protein.rounded())
        let c = Int(nutrients.carbs.rounded())
        let f = Int(nutrients.fat.rounded())
        return "\(normalizedTitle)|\(cal)|\(p)|\(c)|\(f)"
    }
}

/// `score = useCountWeight + recencyWeight` (PRODUCT_SPEC §73).
enum FrequentMealRanking {
    static func score(useCount: Int, lastUsedAt: Date, now: Date = .now) -> Double {
        let days = max(0, now.timeIntervalSince(lastUsedAt) / 86_400)
        let recency = max(0, 14 - days) / 14
        return Double(useCount) * 2.0 + recency * 5.0
    }

    static func ranked(_ templates: [SavedMealTemplate], now: Date = .now, limit: Int = 5) -> [SavedMealTemplate] {
        templates
            .filter { $0.useCount >= 2 }
            .sorted {
                let lhs = score(useCount: $0.useCount, lastUsedAt: $0.lastUsedAt, now: now)
                let rhs = score(useCount: $1.useCount, lastUsedAt: $1.lastUsedAt, now: now)
                if lhs == rhs {
                    return $0.lastUsedAt > $1.lastUsedAt
                }
                return lhs > rhs
            }
            .prefix(limit)
            .map { $0 }
    }
}

protocol SavedMealRepository: Sendable {
    func recordUsage(of meal: MealRecord) async throws
    func frequent(limit: Int) async throws -> [SavedMealTemplate]
    func all() async throws -> [SavedMealTemplate]
    func upsert(_ template: SavedMealTemplate) async throws
    func delete(id: UUID) async throws
    func clear() async throws
}
