import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 40 — Share day summary")
struct Phase40ShareDayTests {
    @Test("Plain text includes totals, target, and sorted meals")
    func formatsWithTarget() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))!
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        let noon = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: day)!

        var oats = MealRecord(
            mealType: .breakfast,
            title: "Oats",
            nutrients: NutrientSet(calories: 350, protein: 12, carbs: 55, fat: 8),
            inputMethod: .quickAdd
        )
        oats.eatenAt = morning

        var bowl = MealRecord(
            mealType: .lunch,
            title: "Chicken bowl",
            nutrients: NutrientSet(calories: 620, protein: 48, carbs: 55, fat: 18),
            inputMethod: .photoScan
        )
        bowl.eatenAt = noon

        let totals = DayNutritionTotals(
            nutrients: oats.nutrients + bowl.nutrients,
            mealCount: 2
        )
        let target = NutritionTargetSnapshot(
            calories: 2_000,
            proteinGrams: 150,
            carbGrams: 200,
            fatGrams: 70,
            source: .manual
        )

        let text = DaySummaryShare.plainText(
            day: day,
            totals: totals,
            target: target,
            meals: [bowl, oats],
            calendar: calendar
        )

        #expect(text.contains("Project Plate"))
        #expect(text.contains("Calories: 970 / 2,000"))
        #expect(text.contains("Protein: 60 / 150 g"))
        #expect(text.contains("Oats"))
        #expect(text.contains("Chicken bowl"))
        #expect(text.contains("Meals (2)"))
        #expect(text.contains("Estimates only"))
        // Chronological: oats before bowl
        let oatsIdx = text.range(of: "Oats")!.lowerBound
        let bowlIdx = text.range(of: "Chicken bowl")!.lowerBound
        #expect(oatsIdx < bowlIdx)
    }

    @Test("Empty day still produces a shareable stub")
    func emptyDay() {
        let text = DaySummaryShare.plainText(
            day: .now,
            totals: .zero,
            target: nil,
            meals: []
        )
        #expect(text.contains("No meals logged."))
        #expect(text.contains("Calories: 0"))
        #expect(!text.contains("Meals ("))
    }
}
