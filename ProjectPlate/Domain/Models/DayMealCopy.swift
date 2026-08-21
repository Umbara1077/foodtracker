import Foundation

/// Copies meals from one calendar day onto another (PRODUCT_SPEC §72 retention).
enum DayMealCopy {
    /// Clones each meal onto `targetDay`, preserving local clock time. Returns how many were saved.
    static func copyMeals(
        from sourceDay: Date,
        to targetDay: Date,
        mealRepository: any MealRepository,
        diary: DiaryService,
        calendar: Calendar = .current
    ) async throws -> Int {
        let sourceMeals = try await mealRepository.meals(on: sourceDay, calendar: calendar)
        guard !sourceMeals.isEmpty else { return 0 }

        let targetStart = calendar.startOfDay(for: targetDay)
        var saved = 0
        for meal in sourceMeals {
            var copy = meal
            copy.id = UUID()
            copy.eatenAt = Self.remap(meal.eatenAt, onto: targetStart, calendar: calendar)
            copy.inputMethod = .duplicated
            copy.healthKitAnchors = nil
            copy.createdAt = .now
            copy.updatedAt = .now
            try await diary.saveMeal(copy)
            saved += 1
        }
        return saved
    }

    /// Moves hour/minute/second from `source` onto `targetStart`'s calendar day.
    static func remap(_ source: Date, onto targetStart: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: source)
        return calendar.date(
            bySettingHour: parts.hour ?? 12,
            minute: parts.minute ?? 0,
            second: parts.second ?? 0,
            of: targetStart
        ) ?? targetStart
    }
}

enum TodayGreeting {
    /// Soft time-of-day greeting (PRODUCT_SPEC §11.2) — not overly personalized.
    static func text(now: Date = .now, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }
}
