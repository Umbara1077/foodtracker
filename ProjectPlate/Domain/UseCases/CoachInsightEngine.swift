import Foundation

struct CoachInsight: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var body: String
    var priority: Int
}

/// Local, rule-based supportive tips (V1.2 AI nutrition coach foundation).
/// No medical advice, calorie shame, or disease claims — PRODUCT_SPEC non-goals.
enum CoachInsightEngine {
    static func insights(
        digest: WeeklyDigest,
        streak: TrackingStreak,
        consistency: ConsistencyStats,
        goalType: GoalType,
        limit: Int = 3
    ) -> [CoachInsight] {
        var tips: [CoachInsight] = []

        if streak.current >= 3 {
            tips.append(
                CoachInsight(
                    id: "streak_keep",
                    title: "Nice tracking rhythm",
                    body: "You’ve logged meals \(streak.current) days in a row. Consistency beats perfection — keep the streak soft and doable.",
                    priority: 30
                )
            )
        } else if streak.current == 0 && digest.daysTracked == 0 {
            tips.append(
                CoachInsight(
                    id: "start_logging",
                    title: "Start with one meal",
                    body: "A single logged lunch is enough to begin. Photo, barcode, or quick add all count.",
                    priority: 10
                )
            )
        }

        if digest.daysTracked >= 4, consistency.targetProtein > 0 {
            let ratio = consistency.averageProtein / max(consistency.targetProtein, 1)
            if ratio < 0.75 {
                tips.append(
                    CoachInsight(
                        id: "protein_nudge",
                        title: "Protein check-in",
                        body: "This week’s average protein is a bit below your target. Adding Greek yogurt, eggs, or beans to one meal can help — no need to overhaul everything.",
                        priority: 40
                    )
                )
            } else if ratio >= 0.95 {
                tips.append(
                    CoachInsight(
                        id: "protein_steady",
                        title: "Protein looks steady",
                        body: "You’re landing near your protein goal on average. That’s a solid foundation for energy and fullness.",
                        priority: 20
                    )
                )
            }
        }

        if digest.daysTracked >= 3, consistency.targetCalories > 0 {
            let calRatio = consistency.averageCalories / max(consistency.targetCalories, 1)
            if calRatio < 0.7 {
                tips.append(
                    CoachInsight(
                        id: "under_fuel",
                        title: "Gentle fuel reminder",
                        body: "Logged days are running lighter than your target. If you feel low-energy, a snack or fuller meal is a valid choice — targets are guides, not rules.",
                        priority: 50
                    )
                )
            } else if calRatio > 1.25, goalType == .loseWeight {
                tips.append(
                    CoachInsight(
                        id: "over_target_soft",
                        title: "Weekends happen",
                        body: "Some days landed above your calorie guide. One higher day doesn’t erase the week — just pick the next meal that feels good.",
                        priority: 35
                    )
                )
            }
        }

        if digest.daysTracked >= 5 {
            tips.append(
                CoachInsight(
                    id: "week_logged",
                    title: "Solid week of data",
                    body: "You tracked \(digest.daysTracked) days. That’s enough signal to notice patterns without obsessing over every number.",
                    priority: 15
                )
            )
        }

        if tips.isEmpty {
            tips.append(
                CoachInsight(
                    id: "default_support",
                    title: "You’re in control",
                    body: "Project Plate is here to estimate and organize — not to judge. Adjust targets anytime in Settings or Progress.",
                    priority: 5
                )
            )
        }

        return Array(
            tips
                .sorted { lhs, rhs in
                    if lhs.priority == rhs.priority { return lhs.id < rhs.id }
                    return lhs.priority > rhs.priority
                }
                .prefix(limit)
        )
    }
}

enum CoachInsightPreference {
    static let enabledKey = "plate.coachInsights.enabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}
