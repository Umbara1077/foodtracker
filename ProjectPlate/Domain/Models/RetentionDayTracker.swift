import Foundation

/// Local retention milestones for day-2 / day-7 return analytics (no PII).
enum RetentionDayTracker {
    static let firstOpenKey = "plate.retention.firstOpenDay"
    static let day2TrackedKey = "plate.retention.day2Tracked"
    static let day7TrackedKey = "plate.retention.day7Tracked"

    /// Call on each cold bootstrap after onboarding. Fires day2/day7 at most once each.
    static func trackReturnIfNeeded(
        now: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        analytics: any AnalyticsClient
    ) {
        let today = calendar.startOfDay(for: now)
        if defaults.object(forKey: firstOpenKey) == nil {
            defaults.set(today, forKey: firstOpenKey)
            return
        }
        guard let first = defaults.object(forKey: firstOpenKey) as? Date else { return }
        let firstDay = calendar.startOfDay(for: first)
        let days = calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0

        if days >= 2, !defaults.bool(forKey: day2TrackedKey) {
            analytics.track(.day2Return)
            defaults.set(true, forKey: day2TrackedKey)
        }
        if days >= 7, !defaults.bool(forKey: day7TrackedKey) {
            analytics.track(.day7Return)
            defaults.set(true, forKey: day7TrackedKey)
        }
    }

    /// Test helper — days between first open and `now`.
    static func daysSinceFirstOpen(
        now: Date,
        calendar: Calendar = .current,
        defaults: UserDefaults
    ) -> Int? {
        guard let first = defaults.object(forKey: firstOpenKey) as? Date else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: first),
            to: calendar.startOfDay(for: now)
        ).day
    }
}
