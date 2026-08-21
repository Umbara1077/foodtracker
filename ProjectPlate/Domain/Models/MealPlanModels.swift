import Foundation

struct PlannedMeal: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    /// Start-of-day for the planned date.
    var dayStart: Date
    var mealType: MealType
    var title: String
    var notes: String?
    /// Optional link to a frequent/saved meal fingerprint.
    var savedMealFingerprint: String?

    init(
        id: UUID = UUID(),
        dayStart: Date,
        mealType: MealType,
        title: String,
        notes: String? = nil,
        savedMealFingerprint: String? = nil
    ) {
        self.id = id
        self.dayStart = dayStart
        self.mealType = mealType
        self.title = title
        self.notes = notes
        self.savedMealFingerprint = savedMealFingerprint
    }
}

protocol MealPlanRepository: Sendable {
    func plans(from start: Date, to end: Date, calendar: Calendar) async throws -> [PlannedMeal]
    func plans(on day: Date, calendar: Calendar) async throws -> [PlannedMeal]
    func upsert(_ plan: PlannedMeal) async throws
    func delete(id: UUID) async throws
    func clear() async throws
}

enum MealPlanPreference {
    static let enabledKey = "plate.mealPlan.enabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}

enum MealPlanMath {
    /// Upcoming days including today (local calendar).
    static func upcomingDays(count: Int, from now: Date = .now, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: now)
        return (0..<max(count, 0)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    static func sorted(_ plans: [PlannedMeal]) -> [PlannedMeal] {
        plans.sorted { lhs, rhs in
            if lhs.dayStart != rhs.dayStart { return lhs.dayStart < rhs.dayStart }
            if lhs.mealType != rhs.mealType {
                return mealTypeOrder(lhs.mealType) < mealTypeOrder(rhs.mealType)
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func mealTypeOrder(_ type: MealType) -> Int {
        switch type {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }
}
