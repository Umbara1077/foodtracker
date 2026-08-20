import Foundation

enum MealInputMethod: String, Codable, Sendable {
    case quickAdd
    case manualSearch
    case barcode
    case photoScan
    case duplicated
    case voice
}

struct MealRecord: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var eatenAt: Date
    var mealType: MealType
    var title: String
    var notes: String?
    var nutrients: NutrientSet
    var inputMethod: MealInputMethod
    var healthKitAnchors: MealHealthKitAnchors?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        eatenAt: Date = .now,
        mealType: MealType,
        title: String,
        notes: String? = nil,
        nutrients: NutrientSet,
        inputMethod: MealInputMethod,
        healthKitAnchors: MealHealthKitAnchors? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.mealType = mealType
        self.title = title
        self.notes = notes
        self.nutrients = nutrients
        self.inputMethod = inputMethod
        self.healthKitAnchors = healthKitAnchors
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DayNutritionTotals: Sendable, Equatable {
    var nutrients: NutrientSet
    var mealCount: Int

    static let zero = DayNutritionTotals(nutrients: .zero, mealCount: 0)
}

enum QuickAddMath {
    /// Atwater energy from macros (PRODUCT_SPEC §18).
    static func caloriesFromMacros(protein: Double, carbs: Double, fat: Double) -> Double {
        protein * 4 + carbs * 4 + fat * 9
    }

    /// Resolve calories for quick add. Returns warning when entered calories diverge from macros.
    static func resolve(
        caloriesText: String?,
        protein: Double?,
        carbs: Double?,
        fat: Double?
    ) -> (calories: Double, warning: String?) {
        let p = protein ?? 0
        let c = carbs ?? 0
        let f = fat ?? 0
        let fromMacros = caloriesFromMacros(protein: p, carbs: c, fat: f)
        let entered = caloriesText.flatMap(Double.init)

        if let entered, entered > 0 {
            let warning: String?
            if (p + c + f) > 0, abs(entered - fromMacros) >= 30 {
                warning = "Entered calories differ from macros (~\(Int(fromMacros.rounded()))). Keeping your calorie value."
            } else {
                warning = nil
            }
            return (entered, warning)
        }

        if fromMacros > 0 {
            return (fromMacros, nil)
        }

        return (0, "Enter calories or macros.")
    }
}

enum DayBoundary {
    /// Local calendar day containing `date`.
    static func start(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func end(of date: Date, calendar: Calendar = .current) -> Date {
        let start = start(of: date, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start
    }

    static func contains(_ date: Date, day: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: day)
    }
}

extension MealType {
    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    static func inferred(from date: Date = .now, calendar: Calendar = .current) -> MealType {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 0..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }
}
