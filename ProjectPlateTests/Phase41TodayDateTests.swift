import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 41 — Today day navigation")
struct Phase41TodayDateTests {
    @Test("isViewingToday matches local calendar day")
    func viewingToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 15))!
        let sameDayMorning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 8))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))!

        #expect(TodayDayNavigation.isViewingToday(sameDayMorning, now: now, calendar: calendar))
        #expect(!TodayDayNavigation.isViewingToday(yesterday, now: now, calendar: calendar))
    }

    @Test("Clamp rejects future days")
    func clampFuture() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 10))!
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 8, day: 22, hour: 9))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 18))!

        let clampedFuture = TodayDayNavigation.clampToPastOrToday(tomorrow, now: now, calendar: calendar)
        #expect(calendar.isDate(clampedFuture, inSameDayAs: now))

        let clampedPast = TodayDayNavigation.clampToPastOrToday(yesterday, now: now, calendar: calendar)
        #expect(calendar.isDate(clampedPast, inSameDayAs: yesterday))
    }

    @Test("Title is Today on current day otherwise short date")
    func titles() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 12))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))!

        #expect(TodayDayNavigation.title(for: now, now: now, calendar: calendar) == "Today")
        let pastTitle = TodayDayNavigation.title(for: yesterday, now: now, calendar: calendar)
        #expect(pastTitle != "Today")
        #expect(pastTitle.contains("20"))
    }
}
