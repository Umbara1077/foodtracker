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
