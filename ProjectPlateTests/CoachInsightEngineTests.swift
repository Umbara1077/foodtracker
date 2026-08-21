import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 25 — Coach insights")
struct CoachInsightEngineTests {
    @Test("Streak insight appears after several logged days")
    func streakTip() {
        let digest = WeeklyDigest(
            weekStart: .now,
            weekEnd: .now,
            daysTracked: 5,
            mealsLogged: 12,
            averageCalories: 2000,
            averageProtein: 120,
            averageFiber: nil,
            averageSugar: nil,
            averageSodiumMg: nil,
            targetCalories: 2100,
            targetProtein: 130,
            weightChangeKg: nil,
            highlight: "Solid week"
        )
        let tips = CoachInsightEngine.insights(
            digest: digest,
            streak: TrackingStreak(current: 5, longest: 5, minimumMealsPerDay: 1, includesToday: true),
            consistency: ConsistencyStats(
                averageCalories: 2000,
                targetCalories: 2100,
                averageProtein: 120,
                targetProtein: 130,
                daysLogged: 5
            ),
            goalType: .maintainWeight
        )
        #expect(tips.contains(where: { $0.id == "streak_keep" }))
        #expect(tips.count <= 3)
    }

    @Test("Low protein produces supportive nudge")
    func proteinNudge() {
        let digest = WeeklyDigest(
            weekStart: .now,
            weekEnd: .now,
            daysTracked: 5,
            mealsLogged: 10,
            averageCalories: 1900,
            averageProtein: 60,
            averageFiber: nil,
            averageSugar: nil,
            averageSodiumMg: nil,
            targetCalories: 2000,
            targetProtein: 140,
            weightChangeKg: nil,
            highlight: "ok"
        )
        let tips = CoachInsightEngine.insights(
            digest: digest,
            streak: .zero,
            consistency: ConsistencyStats(
                averageCalories: 1900,
                targetCalories: 2000,
                averageProtein: 60,
                targetProtein: 140,
                daysLogged: 5
            ),
            goalType: .loseWeight
        )
        #expect(tips.contains(where: { $0.id == "protein_nudge" }))
        #expect(tips.first?.body.contains("overhaul") == true || tips.contains(where: { $0.body.lowercased().contains("protein") }))
    }

    @Test("Empty week still returns a default tip")
    func defaultTip() {
        let tips = CoachInsightEngine.insights(
            digest: .empty,
            streak: .zero,
            consistency: .zero,
            goalType: .trackOnly
        )
        #expect(!tips.isEmpty)
        #expect(tips.contains(where: { $0.id == "start_logging" || $0.id == "default_support" }))
    }

    @Test("Preference defaults on")
    func preference() {
        let defaults = UserDefaults(suiteName: "test.plate.coach.\(UUID().uuidString)")!
        #expect(CoachInsightPreference.isEnabled(defaults: defaults))
        CoachInsightPreference.setEnabled(false, defaults: defaults)
        #expect(!CoachInsightPreference.isEnabled(defaults: defaults))
    }
}
