import Foundation

/// Calendar-day navigation for the Today tab (PRODUCT_SPEC §11.2).
enum TodayDayNavigation {
    /// True when `day` is the same local calendar day as `now`.
    static func isViewingToday(
        _ day: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(day, inSameDayAs: now)
    }

    /// Clamps a picked date to today or earlier (no future diary days on Today).
    static func clampToPastOrToday(
        _ day: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: now)
        return min(start, todayStart)
    }

    /// Navigation title: "Today" on the current day, otherwise a short date.
    static func title(
        for day: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if isViewingToday(day, now: now, calendar: calendar) {
            return "Today"
        }
        return day.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
