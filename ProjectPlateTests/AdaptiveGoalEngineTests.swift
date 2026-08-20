import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 22 — Adaptive goals")
struct AdaptiveGoalEngineTests {
    private let day: TimeInterval = 86_400

    @Test("Observed kg/week needs 14-day span")
    func observedRequiresSpan() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let short = [
            WeightEntry(recordedAt: start, kilograms: 80),
            WeightEntry(recordedAt: start.addingTimeInterval(7 * day), kilograms: 79.5),
        ]
        #expect(AdaptiveGoalEngine.observedKgPerWeek(entries: short) == nil)

        let long = [
            WeightEntry(recordedAt: start, kilograms: 80),
            WeightEntry(recordedAt: start.addingTimeInterval(21 * day), kilograms: 79.1),
        ]
        let rate = AdaptiveGoalEngine.observedKgPerWeek(entries: long)
        #expect(rate != nil)
        #expect(abs((rate ?? 0) - ((79.1 - 80) / 3.0)) < 0.001)
    }

    @Test("Lose-goal stall suggests lower calories")
    func loseStallNudge() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // Flat weight over 21 days while trying to lose → nudge down.
        let weights = [
            WeightEntry(recordedAt: start, kilograms: 80),
            WeightEntry(recordedAt: start.addingTimeInterval(21 * day), kilograms: 80.1),
        ]
        let target = NutritionTargetSnapshot(
            calories: 2000,
            proteinGrams: 140,
            carbGrams: 200,
            fatGrams: 65,
            source: .onboardingEstimate
        )
        let suggestion = AdaptiveGoalEngine.suggestion(
            goalType: .loseWeight,
            macroPreference: .balanced,
            currentTarget: target,
            weightEntries: weights,
            daysLoggedRecently: 10
        )
        #expect(suggestion != nil)
        #expect((suggestion?.suggestedCalories ?? 0) < 2000)
        #expect(suggestion?.title.isEmpty == false)
    }

    @Test("Fast loss suggests easing calories up")
    func fastLossEase() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let weights = [
            WeightEntry(recordedAt: start, kilograms: 80),
            WeightEntry(recordedAt: start.addingTimeInterval(21 * day), kilograms: 77.2),
        ]
        let target = NutritionTargetSnapshot(
            calories: 1800,
            proteinGrams: 140,
            carbGrams: 160,
            fatGrams: 55,
            source: .onboardingEstimate
        )
        let suggestion = AdaptiveGoalEngine.suggestion(
            goalType: .loseWeight,
            macroPreference: .higherProtein,
            currentTarget: target,
            weightEntries: weights,
            daysLoggedRecently: 12
        )
        #expect(suggestion != nil)
        #expect((suggestion?.suggestedCalories ?? 0) > 1800)
    }

    @Test("Track-only never suggests")
    func trackOnlyNil() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let weights = [
            WeightEntry(recordedAt: start, kilograms: 70),
            WeightEntry(recordedAt: start.addingTimeInterval(21 * day), kilograms: 72),
        ]
        let target = NutritionTargetSnapshot(
            calories: 2200,
            proteinGrams: 120,
            carbGrams: 220,
            fatGrams: 70,
            source: .manual
        )
        let suggestion = AdaptiveGoalEngine.suggestion(
            goalType: .trackOnly,
            macroPreference: .balanced,
            currentTarget: target,
            weightEntries: weights,
            daysLoggedRecently: 14
        )
        #expect(suggestion == nil)
    }

    @Test("Preference defaults enabled and dismissal round-trips")
    func preference() {
        let defaults = UserDefaults(suiteName: "test.plate.adaptive.\(UUID().uuidString)")!
        #expect(AdaptiveGoalPreference.isEnabled(defaults: defaults))
        AdaptiveGoalPreference.setEnabled(false, defaults: defaults)
        #expect(!AdaptiveGoalPreference.isEnabled(defaults: defaults))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        AdaptiveGoalPreference.dismiss(forDays: 14, now: now, defaults: defaults)
        #expect(AdaptiveGoalPreference.isDismissed(now: now.addingTimeInterval(day), defaults: defaults))
        #expect(!AdaptiveGoalPreference.isDismissed(now: now.addingTimeInterval(20 * day), defaults: defaults))
    }

    @Test("makeTarget uses adaptive source")
    func makeTarget() {
        let suggestion = AdaptiveGoalSuggestion(
            currentCalories: 2000,
            suggestedCalories: 1850,
            proteinGrams: 130,
            carbGrams: 180,
            fatGrams: 60,
            title: "Tweak",
            detail: "Optional",
            observedKgPerWeek: 0.1,
            expectedKgPerWeek: -0.45
        )
        let target = AdaptiveGoalEngine.makeTarget(from: suggestion)
        #expect(target.calories == 1850)
        #expect(target.source == .adaptiveSuggestion)
    }
}
