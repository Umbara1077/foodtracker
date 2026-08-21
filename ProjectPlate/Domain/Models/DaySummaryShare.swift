import Foundation

/// Builds a plain-text day diary summary for the system share sheet (local-only; no photos).
enum DaySummaryShare {
    static func plainText(
        day: Date,
        totals: DayNutritionTotals,
        target: NutritionTargetSnapshot?,
        meals: [MealRecord],
        calendar: Calendar = .current
    ) -> String {
        var lines: [String] = []
        let dateLabel = day.formatted(date: .complete, time: .omitted)
        lines.append("Project Plate — \(dateLabel)")
        lines.append("")

        let eatenCal = Int(totals.nutrients.calories.rounded())
        if let target {
            lines.append("Calories: \(format(eatenCal)) / \(format(target.calories))")
            lines.append(
                "Protein: \(format(Int(totals.nutrients.protein.rounded()))) / \(format(target.proteinGrams)) g"
            )
            lines.append(
                "Carbs: \(format(Int(totals.nutrients.carbs.rounded()))) / \(format(target.carbGrams)) g"
            )
            lines.append(
                "Fat: \(format(Int(totals.nutrients.fat.rounded()))) / \(format(target.fatGrams)) g"
            )
        } else {
            lines.append("Calories: \(format(eatenCal))")
            lines.append("Protein: \(format(Int(totals.nutrients.protein.rounded()))) g")
            lines.append("Carbs: \(format(Int(totals.nutrients.carbs.rounded()))) g")
            lines.append("Fat: \(format(Int(totals.nutrients.fat.rounded()))) g")
        }

        lines.append("")
        if meals.isEmpty {
            lines.append("No meals logged.")
        } else {
            lines.append("Meals (\(meals.count))")
            let sorted = meals.sorted { $0.eatenAt < $1.eatenAt }
            for meal in sorted {
                let time = meal.eatenAt.formatted(date: .omitted, time: .shortened)
                let cal = Int(meal.nutrients.calories.rounded())
                lines.append("• \(time) \(meal.mealType.title) — \(meal.title) (\(format(cal)) cal)")
            }
        }

        lines.append("")
        lines.append("Estimates only — not medical advice.")
        return lines.joined(separator: "\n")
    }

    private static func format(_ value: Int) -> String {
        value.formatted(
            .number
                .grouping(.automatic)
                .locale(Locale(identifier: "en_US"))
        )
    }
}
