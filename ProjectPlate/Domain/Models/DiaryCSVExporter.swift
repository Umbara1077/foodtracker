import Foundation

enum DiaryCSVExporter {
    static func csv(from meals: [MealRecord]) -> String {
        var lines: [String] = [
            "eaten_at,meal_type,title,calories,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg,input_method",
        ]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        for meal in meals {
            let row: [String] = [
                formatter.string(from: meal.eatenAt),
                meal.mealType.rawValue,
                escape(meal.title),
                string(meal.nutrients.calories),
                string(meal.nutrients.protein),
                string(meal.nutrients.carbs),
                string(meal.nutrients.fat),
                optional(meal.nutrients.fiber),
                optional(meal.nutrients.sugar),
                optional(meal.nutrients.sodiumMg),
                meal.inputMethod.rawValue,
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func string(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    private static func optional(_ value: Double?) -> String {
        guard let value else { return "" }
        return string(value)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
