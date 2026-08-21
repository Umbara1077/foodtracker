import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 36 — Analytics funnel & retention")
struct Phase36AnalyticsTests {
    final class RecordingAnalytics: AnalyticsClient, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var events: [AnalyticsEvent] = []

        func track(_ event: AnalyticsEvent) {
            lock.lock()
            events.append(event)
            lock.unlock()
        }
    }

    @Test("Retention tracker records first open then day2 and day7 once")
    func retentionMilestones() {
        let defaults = UserDefaults(suiteName: "plate.tests.retention.\(UUID().uuidString)")!
        let analytics = RecordingAnalytics()
        let calendar = Calendar(identifier: .gregorian)
        let day0 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!

        RetentionDayTracker.trackReturnIfNeeded(now: day0, calendar: calendar, defaults: defaults, analytics: analytics)
        #expect(analytics.events.isEmpty)
        #expect(RetentionDayTracker.daysSinceFirstOpen(now: day0, calendar: calendar, defaults: defaults) == 0)

        let day2 = calendar.date(byAdding: .day, value: 2, to: day0)!
        RetentionDayTracker.trackReturnIfNeeded(now: day2, calendar: calendar, defaults: defaults, analytics: analytics)
        #expect(analytics.events == [.day2Return])

        RetentionDayTracker.trackReturnIfNeeded(now: day2, calendar: calendar, defaults: defaults, analytics: analytics)
        #expect(analytics.events == [.day2Return])

        let day7 = calendar.date(byAdding: .day, value: 7, to: day0)!
        RetentionDayTracker.trackReturnIfNeeded(now: day7, calendar: calendar, defaults: defaults, analytics: analytics)
        #expect(analytics.events == [.day2Return, .day7Return])
    }

    @Test("Funnel analytics cases cover PRODUCT_SPEC §50 core events")
    func funnelCasesExist() {
        let required: [AnalyticsEvent] = [
            .onboardingStarted,
            .onboardingCompleted,
            .scannerOpened,
            .photoCaptured,
            .scanStarted,
            .scanSucceeded,
            .scanFailed,
            .scanCorrected,
            .mealSaved,
            .barcodeOpened,
            .paywallViewed,
            .purchaseCompleted,
            .purchaseRestored,
            .day2Return,
            .day7Return,
        ]
        #expect(required.count == 15)
    }
}
