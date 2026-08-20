import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Lock Screen / Dynamic Island content for today’s calorie progress (V1.1).
/// Kept in Shared so the app can request updates and the widget extension can render them.
#if canImport(ActivityKit)
struct TodayCaloriesAttributes: ActivityAttributes {
    /// Calendar day this activity represents (start-of-day).
    var dayStart: Date

    struct ContentState: Codable, Hashable, Sendable {
        var remainingCalories: Int
        var eatenCalories: Int
        var targetCalories: Int
        var proteinGrams: Int
        var proteinTargetGrams: Int
        var mealCount: Int
        var updatedAt: Date

        var isOverTarget: Bool { remainingCalories < 0 }

        var headline: String {
            isOverTarget ? "Over target" : "Remaining"
        }

        var remainingDisplay: String {
            "\(abs(remainingCalories))"
        }

        static func from(_ snapshot: TodayWidgetSnapshot) -> ContentState {
            ContentState(
                remainingCalories: snapshot.remainingCalories,
                eatenCalories: snapshot.eatenCalories,
                targetCalories: snapshot.targetCalories,
                proteinGrams: snapshot.proteinGrams,
                proteinTargetGrams: snapshot.proteinTargetGrams,
                mealCount: snapshot.mealCount,
                updatedAt: snapshot.updatedAt
            )
        }
    }
}
#endif

/// Preference + mapping helpers that do not require a live ActivityKit session (unit-testable).
enum TodayLiveActivityPolicy {
    static let preferenceKey = "plate.liveActivity.enabled"

    /// Default on — user can turn off in Settings.
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: preferenceKey) == nil { return true }
        return defaults.bool(forKey: preferenceKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: preferenceKey)
    }

    /// Live Activity is useful once the day has a calorie target (onboarding complete).
    static func shouldPresent(snapshot: TodayWidgetSnapshot) -> Bool {
        snapshot.targetCalories > 0
    }

    static func endOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
    }
}
