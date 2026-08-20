import Foundation

extension WidgetSnapshotStore {
    static func make(
        target: NutritionTargetSnapshot?,
        totals: DayNutritionTotals
    ) -> TodayWidgetSnapshot {
        let goal = target?.calories ?? 0
        let eaten = Int(totals.nutrients.calories.rounded())
        return TodayWidgetSnapshot(
            updatedAt: .now,
            remainingCalories: goal - eaten,
            eatenCalories: eaten,
            targetCalories: goal,
            proteinGrams: Int(totals.nutrients.protein.rounded()),
            proteinTargetGrams: target?.proteinGrams ?? 0,
            mealCount: totals.mealCount
        )
    }
}
