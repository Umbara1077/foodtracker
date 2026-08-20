import Foundation

enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
}

enum MealConfidence: String, Codable, Sendable, Equatable {
    case high
    case medium
    case low

    var userLabel: String {
        switch self {
        case .high: "Strong match"
        case .medium: "Good estimate"
        case .low: "Check this one"
        }
    }

    static func from(score: Double) -> MealConfidence {
        if score >= 0.85 { return .high }
        if score >= 0.65 { return .medium }
        return .low
    }
}

struct NutrientSet: Codable, Sendable, Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sugar: Double?
    var sodiumMg: Double?

    static let zero = NutrientSet(calories: 0, protein: 0, carbs: 0, fat: 0)

    static func + (lhs: NutrientSet, rhs: NutrientSet) -> NutrientSet {
        NutrientSet(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            fiber: optionalSum(lhs.fiber, rhs.fiber),
            sugar: optionalSum(lhs.sugar, rhs.sugar),
            sodiumMg: optionalSum(lhs.sodiumMg, rhs.sodiumMg)
        )
    }

    private static func optionalSum(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (x?, y?): x + y
        case let (x?, nil): x
        case let (nil, y?): y
        case (nil, nil): nil
        }
    }
}
