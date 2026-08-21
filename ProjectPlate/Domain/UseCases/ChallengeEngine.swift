import Foundation

struct WeeklyChallenge: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var current: Int
    var goal: Int
    var unitLabel: String
    var priority: Int

    var isComplete: Bool { current >= goal }

    var progressFraction: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1)
    }

    var statusLine: String {
        if isComplete {
            return "Complete — nice consistency."
        }
        let remaining = goal - current
        return "\(remaining) \(unitLabel) to go — no pressure if this week is lighter."
    }
}

/// Soft weekly challenges layered on tracking (PRODUCT_SPEC §6.3 Challenges/streaks).
/// Supportive only — never shames incomplete challenges or uses loss framing.
enum ChallengeEngine {
    static func challenges(
        digest: WeeklyDigest,
        dailyTotals: [(date: Date, totals: DayNutritionTotals)],
        target: NutritionTargetSnapshot?,
        limit: Int = 3
    ) -> [WeeklyChallenge] {
        var items: [WeeklyChallenge] = []

        items.append(
            WeeklyChallenge(
                id: "days_tracked_5",
                title: "Track 5 days",
                detail: "Log at least one meal on five different days this week.",
                current: min(digest.daysTracked, 5),
                goal: 5,
                unitLabel: remainingUnit(goal: 5, current: digest.daysTracked, singular: "day", plural: "days"),
                priority: 30
            )
        )

        items.append(
            WeeklyChallenge(
                id: "meals_12",
                title: "Log 12 meals",
                detail: "A gentle volume goal — quick adds and favorites count.",
                current: min(digest.mealsLogged, 12),
                goal: 12,
                unitLabel: remainingUnit(goal: 12, current: digest.mealsLogged, singular: "meal", plural: "meals"),
                priority: 20
            )
        )

        if let target, target.proteinGrams > 0 {
            let proteinDays = dailyTotals.filter { day in
                guard day.totals.mealCount > 0 else { return false }
                return day.totals.nutrients.protein >= Double(target.proteinGrams) * 0.9
            }.count
            items.append(
                WeeklyChallenge(
                    id: "protein_days_3",
                    title: "Protein-steady days",
                    detail: "Land near your protein target on three logged days (~90%+).",
                    current: min(proteinDays, 3),
                    goal: 3,
                    unitLabel: remainingUnit(goal: 3, current: proteinDays, singular: "day", plural: "days"),
                    priority: 40
                )
            )
        }

        return Array(
            items
                .sorted { lhs, rhs in
                    if lhs.isComplete != rhs.isComplete { return !lhs.isComplete && rhs.isComplete }
                    if lhs.priority == rhs.priority { return lhs.id < rhs.id }
                    return lhs.priority > rhs.priority
                }
                .prefix(limit)
        )
    }

    private static func remainingUnit(goal: Int, current: Int, singular: String, plural: String) -> String {
        max(goal - current, 1) == 1 ? singular : plural
    }
}

enum ChallengePreference {
    static let enabledKey = "plate.challenges.enabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}
