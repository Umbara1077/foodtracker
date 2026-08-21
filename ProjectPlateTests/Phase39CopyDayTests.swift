import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 39 — Copy previous day")
struct Phase39CopyDayTests {
    @Test("Remap keeps clock time on the target calendar day")
    func remapPreservesClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let sourceDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))!
        let source = calendar.date(bySettingHour: 8, minute: 30, second: 15, of: sourceDay)!
        let targetStart = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))!

        let remapped = DayMealCopy.remap(source, onto: targetStart, calendar: calendar)
        #expect(calendar.isDate(remapped, inSameDayAs: targetStart))
        #expect(calendar.component(.hour, from: remapped) == 8)
        #expect(calendar.component(.minute, from: remapped) == 30)
        #expect(calendar.component(.second, from: remapped) == 15)
    }

    @Test("Copy clones meals onto today with new ids")
    func copyMealsCreatesNewRecords() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 9))!
        let breakfastTime = calendar.date(bySettingHour: 7, minute: 45, second: 0, of: yesterday)!

        var breakfast = MealRecord(
            mealType: .breakfast,
            title: "Oats",
            nutrients: NutrientSet(calories: 350, protein: 12, carbs: 55, fat: 8),
            inputMethod: .quickAdd
        )
        breakfast.eatenAt = breakfastTime

        let meals = InMemoryMealRepository(meals: [breakfast])
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: nil),
            health: NoOpHealthSyncClient(),
            savedMeals: InMemorySavedMealRepository()
        )

        let count = try await DayMealCopy.copyMeals(
            from: yesterday,
            to: today,
            mealRepository: meals,
            diary: diary,
            calendar: calendar
        )
        #expect(count == 1)

        let todayMeals = try await meals.meals(on: today, calendar: calendar)
        #expect(todayMeals.count == 1)
        #expect(todayMeals[0].id != breakfast.id)
        #expect(todayMeals[0].title == "Oats")
        #expect(todayMeals[0].inputMethod == .duplicated)
        #expect(calendar.component(.hour, from: todayMeals[0].eatenAt) == 7)
        #expect(calendar.component(.minute, from: todayMeals[0].eatenAt) == 45)
        #expect(calendar.isDate(todayMeals[0].eatenAt, inSameDayAs: today))

        let yesterdayMeals = try await meals.meals(on: yesterday, calendar: calendar)
        #expect(yesterdayMeals.count == 1)
    }

    @Test("Empty source day copies nothing")
    func emptySource() async throws {
        let meals = InMemoryMealRepository()
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: nil),
            health: NoOpHealthSyncClient(),
            savedMeals: InMemorySavedMealRepository()
        )
        let count = try await DayMealCopy.copyMeals(
            from: .now,
            to: .now,
            mealRepository: meals,
            diary: diary
        )
        #expect(count == 0)
    }

    @Test("Greeting follows hour of day")
    func greetingBands() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))!

        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        let afternoon = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day)!
        let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
        let late = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)!

        #expect(TodayGreeting.text(now: morning, calendar: calendar) == "Good morning")
        #expect(TodayGreeting.text(now: afternoon, calendar: calendar) == "Good afternoon")
        #expect(TodayGreeting.text(now: evening, calendar: calendar) == "Good evening")
        #expect(TodayGreeting.text(now: late, calendar: calendar) == "Hello")
    }
}
