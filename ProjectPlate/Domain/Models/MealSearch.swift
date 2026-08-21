import Foundation

/// Case-insensitive meal title / notes / type filter for History search.
enum MealSearch {
    static func matches(_ meal: MealRecord, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let needle = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let haystacks = [
            meal.title,
            meal.notes ?? "",
            meal.mealType.title,
        ]
        return haystacks.contains { field in
            field.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(needle)
        }
    }

    static func filter(_ meals: [MealRecord], query: String) -> [MealRecord] {
        meals.filter { matches($0, query: query) }
    }
}
