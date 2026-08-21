import Testing
@testable import ProjectPlate
import Foundation

struct ProgressMathTests {
    @Test("Weight change is last minus first")
    func weightChange() {
        let entries = [
            WeightEntry(recordedAt: Date(timeIntervalSince1970: 1000), kilograms: 80),
            WeightEntry(recordedAt: Date(timeIntervalSince1970: 2000), kilograms: 78.5),
            WeightEntry(recordedAt: Date(timeIntervalSince1970: 3000), kilograms: 78),
        ]
        #expect(ProgressMath.weightChangeKg(entries: entries) == -2)
        #expect(ProgressMath.weightChangeKg(entries: [entries[0]]) == nil)
    }

    @Test("Consistency averages only days with meals")
    func consistency() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!
        let target = NutritionTargetSnapshot(
            calories: 2000,
            proteinGrams: 150,
            carbGrams: 200,
            fatGrams: 60,
            source: .manual
        )
        let stats = ProgressMath.consistency(
            dailyTotals: [
                (day1, DayNutritionTotals(nutrients: NutrientSet(calories: 1800, protein: 140, carbs: 0, fat: 0), mealCount: 2)),
                (day2, DayNutritionTotals(nutrients: .zero, mealCount: 0)),
                (day3, DayNutritionTotals(nutrients: NutrientSet(calories: 2200, protein: 160, carbs: 0, fat: 0), mealCount: 3)),
            ],
            target: target
        )
        #expect(stats.daysLogged == 2)
        #expect(stats.averageCalories == 2000)
        #expect(stats.averageProtein == 150)
        #expect(stats.targetCalories == 2000)
    }

    @Test("Weekly digest averages logged days and builds a supportive highlight")
    func weeklyDigest() {
        let calendar = Calendar(identifier: .gregorian)
        let weekEnd = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!
        let mid = calendar.date(byAdding: .day, value: 3, to: weekStart)!
        let target = NutritionTargetSnapshot(
            calories: 2000,
            proteinGrams: 150,
            carbGrams: 200,
            fatGrams: 60,
            source: .manual
        )
        let digest = ProgressMath.weeklyDigest(
            dailyTotals: [
                (weekStart, DayNutritionTotals(nutrients: NutrientSet(calories: 1800, protein: 140, carbs: 0, fat: 0), mealCount: 2)),
                (mid, DayNutritionTotals(nutrients: NutrientSet(calories: 2200, protein: 160, carbs: 0, fat: 0), mealCount: 3)),
            ],
            weightEntries: [
                WeightEntry(recordedAt: weekStart, kilograms: 80),
                WeightEntry(recordedAt: weekEnd, kilograms: 79.4),
            ],
            target: target,
            weekStart: weekStart,
            weekEnd: weekEnd
        )
        #expect(digest.daysTracked == 2)
        #expect(digest.mealsLogged == 5)
        #expect(digest.averageCalories == 2000)
        #expect(digest.averageProtein == 150)
        #expect(abs((digest.weightChangeKg ?? 0) - (-0.6)) < 0.0001)
        #expect(digest.highlight.contains("Protein") || digest.highlight.contains("tracked"))
    }

    @Test("Empty week digest avoids shame copy")
    func emptyWeekHighlight() {
        let highlight = ProgressMath.weeklyHighlight(
            daysTracked: 0,
            mealsLogged: 0,
            averageProtein: 0,
            targetProtein: 150,
            weightChangeKg: nil
        )
        #expect(highlight.contains("Log a couple meals"))
        #expect(!highlight.lowercased().contains("fail"))
        #expect(!highlight.lowercased().contains("miss"))
    }

    @Test("Tracking streak counts consecutive qualified days without shame copy")
    func trackingStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let d1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let d2 = calendar.date(byAdding: .day, value: -1, to: today)!
        let earlier = calendar.date(byAdding: .day, value: -10, to: today)!
        let earlier2 = calendar.date(byAdding: .day, value: -9, to: today)!
        let earlier3 = calendar.date(byAdding: .day, value: -8, to: today)!
        let streak = ProgressMath.trackingStreak(
            dailyTotals: [
                (earlier, DayNutritionTotals(nutrients: .zero, mealCount: 2)),
                (earlier2, DayNutritionTotals(nutrients: .zero, mealCount: 2)),
                (earlier3, DayNutritionTotals(nutrients: .zero, mealCount: 2)),
                (d1, DayNutritionTotals(nutrients: .zero, mealCount: 1)),
                (d2, DayNutritionTotals(nutrients: .zero, mealCount: 2)),
                (today, DayNutritionTotals(nutrients: .zero, mealCount: 1)),
            ],
            now: today,
            calendar: calendar
        )
        #expect(streak.current == 3)
        #expect(streak.longest == 3)
        #expect(streak.includesToday)
        #expect(streak.title == "3-day streak")
        #expect(!streak.subtitle.lowercased().contains("lost"))
        #expect(!streak.subtitle.lowercased().contains("broke"))
    }

    @Test("Empty today keeps streak through yesterday")
    func streakHoldsYesterday() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let streak = ProgressMath.trackingStreak(
            dailyTotals: [
                (yesterday, DayNutritionTotals(nutrients: .zero, mealCount: 2)),
            ],
            now: today,
            calendar: calendar
        )
        #expect(streak.current == 1)
        #expect(!streak.includesToday)
        #expect(streak.subtitle.contains("keep"))
    }

    @Test("Progress range start is before end")
    func ranges() {
        let end = Date()
        for range in ProgressRange.allCases {
            #expect(range.startDate(relativeTo: end) <= end)
        }
    }

    @Test("In-memory weight repository round-trips")
    func weightRepo() async throws {
        let repo = InMemoryWeightRepository()
        let entry = WeightEntry(kilograms: 70.5, note: "morning")
        try await repo.save(entry)
        let latest = try await repo.latest()
        #expect(latest?.kilograms == 70.5)
        let listed = try await repo.entries(
            from: Date().addingTimeInterval(-3600),
            to: Date().addingTimeInterval(3600)
        )
        #expect(listed.count == 1)
    }
}
