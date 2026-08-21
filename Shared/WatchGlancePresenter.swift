import Foundation

/// Display mapping for the Apple Watch Today glance (PRODUCT_SPEC §6.3).
/// Kept in Shared so iOS unit tests can cover copy without a watchOS host.
enum WatchGlancePresenter {
    struct Content: Equatable, Sendable {
        var headline: String
        var caloriesValue: String
        var caloriesCaption: String
        var proteinLine: String
        var mealsLine: String
        var emptyState: Bool
    }

    static func content(from snapshot: TodayWidgetSnapshot?) -> Content {
        guard let snapshot, snapshot.targetCalories > 0 else {
            return Content(
                headline: "Project Plate",
                caloriesValue: "—",
                caloriesCaption: "Open iPhone to set a target",
                proteinLine: "Protein appears after onboarding",
                mealsLine: "Log a meal on iPhone",
                emptyState: true
            )
        }

        let protein: String
        if snapshot.proteinTargetGrams > 0 {
            protein = "P \(snapshot.proteinGrams)/\(snapshot.proteinTargetGrams)g"
        } else {
            protein = "P \(snapshot.proteinGrams)g"
        }

        return Content(
            headline: snapshot.headline,
            caloriesValue: snapshot.remainingDisplay,
            caloriesCaption: snapshot.isOverTarget
                ? "\(snapshot.eatenCalories) eaten · \(snapshot.targetCalories) goal"
                : "of \(snapshot.targetCalories) cal",
            proteinLine: protein,
            mealsLine: snapshot.mealCount == 1
                ? "1 meal logged"
                : "\(snapshot.mealCount) meals logged",
            emptyState: false
        )
    }
}
