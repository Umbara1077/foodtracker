import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 27 — Weekly challenges")
struct ChallengeEngineTests {
    @Test("Days and meals challenges reflect digest")
    func daysAndMeals() {
        let digest = WeeklyDigest(
            weekStart: .now,
            weekEnd: .now,
            daysTracked: 3,
            mealsLogged: 8,
            averageCalories: 2000,
            averageProtein: 120,
            averageFiber: nil,
            averageSugar: nil,
            averageSodiumMg: nil,
            targetCalories: 2100,
            targetProtein: 140,
            weightChangeKg: nil,
            highlight: "ok"
        )
        let items = ChallengeEngine.challenges(
            digest: digest,
            dailyTotals: [],
            target: nil
        )
        let days = items.first { $0.id == "days_tracked_5" }
        let meals = items.first { $0.id == "meals_12" }
        #expect(days?.current == 3)
        #expect(days?.isComplete == false)
        #expect(meals?.current == 8)
        #expect(items.contains(where: { $0.id == "protein_days_3" }) == false)
    }

    @Test("Protein-steady days count near-target days")
    func proteinDays() {
        let calendar = Calendar(identifier: .gregorian)
        let day0 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let day1 = calendar.date(byAdding: .day, value: 1, to: day0)!
        let day2 = calendar.date(byAdding: .day, value: 2, to: day0)!
        let target = NutritionTargetSnapshot(
            calories: 2000,
            proteinGrams: 100,
            carbGrams: 200,
            fatGrams: 60,
            source: .manual
        )
        let digest = WeeklyDigest(
            weekStart: day0,
            weekEnd: day2,
            daysTracked: 3,
            mealsLogged: 6,
            averageCalories: 2000,
            averageProtein: 100,
            averageFiber: nil,
            averageSugar: nil,
            averageSodiumMg: nil,
            targetCalories: 2000,
            targetProtein: 100,
            weightChangeKg: nil,
            highlight: "ok"
        )
        let items = ChallengeEngine.challenges(
            digest: digest,
            dailyTotals: [
                (day0, DayNutritionTotals(nutrients: NutrientSet(calories: 2000, protein: 95, carbs: 0, fat: 0), mealCount: 2)),
                (day1, DayNutritionTotals(nutrients: NutrientSet(calories: 2000, protein: 50, carbs: 0, fat: 0), mealCount: 2)),
                (day2, DayNutritionTotals(nutrients: NutrientSet(calories: 2000, protein: 110, carbs: 0, fat: 0), mealCount: 2)),
            ],
            target: target
        )
        let protein = items.first { $0.id == "protein_days_3" }
        #expect(protein?.current == 2)
        #expect(protein?.isComplete == false)
        #expect(protein?.statusLine.lowercased().contains("pressure") == true)
    }

    @Test("Completed challenges sort after incomplete")
    func sortIncompleteFirst() {
        let digest = WeeklyDigest(
            weekStart: .now,
            weekEnd: .now,
            daysTracked: 5,
            mealsLogged: 3,
            averageCalories: 2000,
            averageProtein: 100,
            averageFiber: nil,
            averageSugar: nil,
            averageSodiumMg: nil,
            targetCalories: 2000,
            targetProtein: 100,
            weightChangeKg: nil,
            highlight: "ok"
        )
        let items = ChallengeEngine.challenges(
            digest: digest,
            dailyTotals: [],
            target: nil,
            limit: 3
        )
        #expect(items.first?.id == "meals_12")
        #expect(items.contains(where: { $0.id == "days_tracked_5" && $0.isComplete }))
    }

    @Test("Preference defaults on")
    func preference() {
        let defaults = UserDefaults(suiteName: "test.plate.challenges.\(UUID().uuidString)")!
        #expect(ChallengePreference.isEnabled(defaults: defaults))
        ChallengePreference.setEnabled(false, defaults: defaults)
        #expect(!ChallengePreference.isEnabled(defaults: defaults))
    }

    @Test("Incomplete copy avoids shame words")
    func noShameCopy() {
        let challenge = WeeklyChallenge(
            id: "x",
            title: "t",
            detail: "d",
            current: 1,
            goal: 5,
            unitLabel: "days",
            priority: 1
        )
        let line = challenge.statusLine.lowercased()
        #expect(!line.contains("fail"))
        #expect(!line.contains("miss"))
        #expect(!line.contains("lost"))
    }
}
