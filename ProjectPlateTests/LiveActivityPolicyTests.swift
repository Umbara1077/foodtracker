import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 19 — Live Activity policy")
struct LiveActivityPolicyTests {
    @Test("Default preference is enabled")
    func defaultEnabled() {
        let defaults = UserDefaults(suiteName: "test.plate.live.\(UUID().uuidString)")!
        #expect(TodayLiveActivityPolicy.isEnabled(defaults: defaults))
    }

    @Test("Preference round-trips")
    func preferenceToggle() {
        let defaults = UserDefaults(suiteName: "test.plate.live.\(UUID().uuidString)")!
        TodayLiveActivityPolicy.setEnabled(false, defaults: defaults)
        #expect(!TodayLiveActivityPolicy.isEnabled(defaults: defaults))
        TodayLiveActivityPolicy.setEnabled(true, defaults: defaults)
        #expect(TodayLiveActivityPolicy.isEnabled(defaults: defaults))
    }

    @Test("Present only when calorie target exists")
    func shouldPresent() {
        var snapshot = TodayWidgetSnapshot.placeholder
        #expect(TodayLiveActivityPolicy.shouldPresent(snapshot: snapshot))
        snapshot.targetCalories = 0
        #expect(!TodayLiveActivityPolicy.shouldPresent(snapshot: snapshot))
    }

    @Test("End of day is next midnight")
    func endOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2024,
            month: 6,
            day: 15,
            hour: 14
        )
        let afternoon = calendar.date(from: components)!
        let end = TodayLiveActivityPolicy.endOfDay(for: afternoon, calendar: calendar)
        let expectedStart = calendar.startOfDay(for: afternoon)
        let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)!
        #expect(end == expectedEnd)
    }

    #if canImport(ActivityKit)
    @Test("Content state maps from widget snapshot")
    func contentStateMapping() {
        let snapshot = TodayWidgetSnapshot(
            updatedAt: Date(timeIntervalSince1970: 1_720_000_000),
            remainingCalories: 400,
            eatenCalories: 1600,
            targetCalories: 2000,
            proteinGrams: 110,
            proteinTargetGrams: 140,
            mealCount: 3
        )
        let state = TodayCaloriesAttributes.ContentState.from(snapshot)
        #expect(state.remainingCalories == 400)
        #expect(state.eatenCalories == 1600)
        #expect(state.proteinGrams == 110)
        #expect(state.mealCount == 3)
        #expect(state.headline == "Remaining")
        #expect(state.remainingDisplay == "400")
    }

    @Test("Over-target content state")
    func overTargetState() {
        let snapshot = TodayWidgetSnapshot(
            updatedAt: .now,
            remainingCalories: -80,
            eatenCalories: 2080,
            targetCalories: 2000,
            proteinGrams: 150,
            proteinTargetGrams: 140,
            mealCount: 4
        )
        let state = TodayCaloriesAttributes.ContentState.from(snapshot)
        #expect(state.isOverTarget)
        #expect(state.headline == "Over target")
        #expect(state.remainingDisplay == "80")
    }
    #endif
}
