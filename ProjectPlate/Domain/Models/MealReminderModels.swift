import Foundation
import UserNotifications

/// Optional meal logging reminders (PRODUCT_SPEC §68). Permission is requested only after the user enables reminders.
enum MealReminderPreference {
    static let enabledKey = "plate.mealReminders.enabled"
    static let breakfastHourKey = "plate.mealReminders.breakfastHour"
    static let lunchHourKey = "plate.mealReminders.lunchHour"
    static let dinnerHourKey = "plate.mealReminders.dinnerHour"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }

    static func hour(for meal: ReminderMeal, defaults: UserDefaults = .standard) -> Int {
        let key: String
        let fallback: Int
        switch meal {
        case .breakfast: key = breakfastHourKey; fallback = 8
        case .lunch: key = lunchHourKey; fallback = 12
        case .dinner: key = dinnerHourKey; fallback = 18
        }
        let stored = defaults.object(forKey: key) as? Int
        return stored ?? fallback
    }

    static func setHour(_ hour: Int, for meal: ReminderMeal, defaults: UserDefaults = .standard) {
        let clamped = min(23, max(0, hour))
        switch meal {
        case .breakfast: defaults.set(clamped, forKey: breakfastHourKey)
        case .lunch: defaults.set(clamped, forKey: lunchHourKey)
        case .dinner: defaults.set(clamped, forKey: dinnerHourKey)
        }
    }
}

enum ReminderMeal: String, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Morning"
        case .lunch: "Midday"
        case .dinner: "Evening"
        }
    }

    /// Guilt-free copy — never shame the user for missing a log.
    var notificationBody: String {
        switch self {
        case .breakfast: "Want to add anything from this morning?"
        case .lunch: "Quick pause — log lunch if you like."
        case .dinner: "Anytime works — add dinner when you’re ready."
        }
    }

    var notificationIdentifier: String {
        "plate.reminder.\(rawValue)"
    }
}

enum MealReminderScheduler {
    static func refresh(defaults: UserDefaults = .standard) async {
        let center = UNUserNotificationCenter.current()
        let ids = ReminderMeal.allCases.map(\.notificationIdentifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)

        guard MealReminderPreference.isEnabled(defaults: defaults) else { return }

        let settings = await center.notificationSettings()
        var authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        if settings.authorizationStatus == .notDetermined {
            authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        guard authorized else {
            MealReminderPreference.setEnabled(false, defaults: defaults)
            return
        }

        for meal in ReminderMeal.allCases {
            var components = DateComponents()
            components.hour = MealReminderPreference.hour(for: meal, defaults: defaults)
            components.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "Project Plate"
            content.body = meal.notificationBody
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: meal.notificationIdentifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
