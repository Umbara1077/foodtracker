import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 29 — Meal planning")
struct MealPlanTests {
    @Test("Upcoming days includes today and forward")
    func upcomingDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let days = MealPlanMath.upcomingDays(count: 3, from: now, calendar: calendar)
        #expect(days.count == 3)
        #expect(calendar.isDate(days[0], inSameDayAs: now))
        #expect(calendar.dateComponents([.day], from: days[0], to: days[2]).day == 2)
    }

    @Test("In-memory repository filters by day and sorts meal types")
    func repositoryDayFilter() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        let repo = InMemoryMealPlanRepository(items: [
            PlannedMeal(dayStart: day, mealType: .dinner, title: "Salmon"),
            PlannedMeal(dayStart: day, mealType: .breakfast, title: "Oats"),
            PlannedMeal(dayStart: next, mealType: .lunch, title: "Bowl"),
        ])
        let today = try await repo.plans(on: day, calendar: calendar)
        #expect(today.map(\.title) == ["Oats", "Salmon"])
        #expect(today.first?.mealType == .breakfast)
    }

    @Test("UserDefaults repository round-trips")
    func defaultsRoundTrip() async throws {
        let suite = "plate.test.mealplan.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now)
        let repo = UserDefaultsMealPlanRepository(defaults: defaults)
        let plan = PlannedMeal(dayStart: day, mealType: .lunch, title: "Greek yogurt bowl")
        try await repo.upsert(plan)
        let loaded = try await repo.plans(on: day, calendar: calendar)
        #expect(loaded.count == 1)
        #expect(loaded.first?.title == "Greek yogurt bowl")
        try await repo.delete(id: plan.id)
        #expect(try await repo.plans(on: day, calendar: calendar).isEmpty)
    }

    @Test("Preference defaults on")
    func preference() {
        let suite = "plate.test.mealplan.pref.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(MealPlanPreference.isEnabled(defaults: defaults))
        MealPlanPreference.setEnabled(false, defaults: defaults)
        #expect(!MealPlanPreference.isEnabled(defaults: defaults))
    }
}
