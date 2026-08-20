import Foundation

enum WeightSource: String, Codable, Sendable {
    case local
    case healthKit
}

struct WeightEntry: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var recordedAt: Date
    var kilograms: Double
    var note: String?
    var source: WeightSource
    var healthKitUUID: String?

    init(
        id: UUID = UUID(),
        recordedAt: Date = .now,
        kilograms: Double,
        note: String? = nil,
        source: WeightSource = .local,
        healthKitUUID: String? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.kilograms = kilograms
        self.note = note
        self.source = source
        self.healthKitUUID = healthKitUUID
    }
}

enum ProgressRange: String, CaseIterable, Identifiable, Sendable {
    case days7
    case days30
    case months3
    case months6
    case year1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days7: "7D"
        case .days30: "30D"
        case .months3: "3M"
        case .months6: "6M"
        case .year1: "1Y"
        }
    }

    func startDate(relativeTo end: Date = .now, calendar: Calendar = .current) -> Date {
        switch self {
        case .days7:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end)) ?? end
        case .days30:
            return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: end)) ?? end
        case .months3:
            return calendar.date(byAdding: .month, value: -3, to: calendar.startOfDay(for: end)) ?? end
        case .months6:
            return calendar.date(byAdding: .month, value: -6, to: calendar.startOfDay(for: end)) ?? end
        case .year1:
            return calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: end)) ?? end
        }
    }
}

struct ConsistencyStats: Sendable, Equatable {
    var averageCalories: Double
    var targetCalories: Double
    var averageProtein: Double
    var targetProtein: Double
    var daysLogged: Int

    static let zero = ConsistencyStats(
        averageCalories: 0,
        targetCalories: 0,
        averageProtein: 0,
        targetProtein: 0,
        daysLogged: 0
    )

    var calorieRatio: Double {
        guard targetCalories > 0 else { return 0 }
        return averageCalories / targetCalories
    }

    var proteinRatio: Double {
        guard targetProtein > 0 else { return 0 }
        return averageProtein / targetProtein
    }
}

/// Rolling 7-day summary for Progress (PRODUCT_SPEC §94 weekly summary).
struct WeeklyDigest: Sendable, Equatable {
    var weekStart: Date
    var weekEnd: Date
    var daysTracked: Int
    var mealsLogged: Int
    var averageCalories: Double
    var averageProtein: Double
    var targetCalories: Double
    var targetProtein: Double
    var weightChangeKg: Double?
    var highlight: String

    static let empty = WeeklyDigest(
        weekStart: .now,
        weekEnd: .now,
        daysTracked: 0,
        mealsLogged: 0,
        averageCalories: 0,
        averageProtein: 0,
        targetCalories: 0,
        targetProtein: 0,
        weightChangeKg: nil,
        highlight: "Log a couple meals this week to see your digest."
    )
}

enum ProgressMath {
    static func weightChangeKg(entries: [WeightEntry]) -> Double? {
        let sorted = entries.sorted { $0.recordedAt < $1.recordedAt }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else { return nil }
        return last.kilograms - first.kilograms
    }

    static func consistency(
        dailyTotals: [(date: Date, totals: DayNutritionTotals)],
        target: NutritionTargetSnapshot?
    ) -> ConsistencyStats {
        let logged = dailyTotals.filter { $0.totals.mealCount > 0 }
        guard !logged.isEmpty else {
            return ConsistencyStats(
                averageCalories: 0,
                targetCalories: Double(target?.calories ?? 0),
                averageProtein: 0,
                targetProtein: Double(target?.proteinGrams ?? 0),
                daysLogged: 0
            )
        }
        let avgCal = logged.map(\.totals.nutrients.calories).reduce(0, +) / Double(logged.count)
        let avgPro = logged.map(\.totals.nutrients.protein).reduce(0, +) / Double(logged.count)
        return ConsistencyStats(
            averageCalories: avgCal,
            targetCalories: Double(target?.calories ?? 0),
            averageProtein: avgPro,
            targetProtein: Double(target?.proteinGrams ?? 0),
            daysLogged: logged.count
        )
    }

    static func weeklyDigest(
        dailyTotals: [(date: Date, totals: DayNutritionTotals)],
        weightEntries: [WeightEntry],
        target: NutritionTargetSnapshot?,
        weekStart: Date,
        weekEnd: Date
    ) -> WeeklyDigest {
        let loggedDays = dailyTotals.filter { $0.totals.mealCount > 0 }
        let mealsLogged = loggedDays.reduce(0) { $0 + $1.totals.mealCount }
        let daysTracked = loggedDays.count
        let avgCal: Double
        let avgPro: Double
        if loggedDays.isEmpty {
            avgCal = 0
            avgPro = 0
        } else {
            avgCal = loggedDays.map(\.totals.nutrients.calories).reduce(0, +) / Double(loggedDays.count)
            avgPro = loggedDays.map(\.totals.nutrients.protein).reduce(0, +) / Double(loggedDays.count)
        }
        let targetCal = Double(target?.calories ?? 0)
        let targetPro = Double(target?.proteinGrams ?? 0)
        let weightDelta = weightChangeKg(entries: weightEntries)
        return WeeklyDigest(
            weekStart: weekStart,
            weekEnd: weekEnd,
            daysTracked: daysTracked,
            mealsLogged: mealsLogged,
            averageCalories: avgCal,
            averageProtein: avgPro,
            targetCalories: targetCal,
            targetProtein: targetPro,
            weightChangeKg: weightDelta,
            highlight: weeklyHighlight(
                daysTracked: daysTracked,
                mealsLogged: mealsLogged,
                averageProtein: avgPro,
                targetProtein: targetPro,
                weightChangeKg: weightDelta
            )
        )
    }

    /// Supportive copy only — no calorie shame (PRODUCT_SPEC §94).
    static func weeklyHighlight(
        daysTracked: Int,
        mealsLogged: Int,
        averageProtein: Double,
        targetProtein: Double,
        weightChangeKg: Double?
    ) -> String {
        if daysTracked == 0 {
            return "Log a couple meals this week to see your digest."
        }
        if daysTracked >= 5 {
            return "Solid week of tracking — \(daysTracked) days logged."
        }
        if targetProtein > 0, averageProtein >= targetProtein * 0.9 {
            return "Protein stayed close to your target this week."
        }
        if mealsLogged >= 10 {
            return "You’ve built a useful log this week (\(mealsLogged) meals)."
        }
        if let delta = weightChangeKg, abs(delta) >= 0.2 {
            return "You tracked \(daysTracked) days. Weight moved \(String(format: "%+.1f", delta)) kg over the week."
        }
        return "You tracked \(daysTracked) day\(daysTracked == 1 ? "" : "s") this week."
    }
}

protocol WeightRepository: Sendable {
    func entries(from start: Date, to end: Date) async throws -> [WeightEntry]
    func latest() async throws -> WeightEntry?
    func save(_ entry: WeightEntry) async throws
    func delete(id: UUID) async throws
}
