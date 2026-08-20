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
