import Foundation

/// Copy helpers for the meal-delete undo banner.
enum MealDeleteUndo {
    static func bannerMessage(for meal: MealRecord) -> String {
        "Deleted \"\(meal.title)\""
    }
}
