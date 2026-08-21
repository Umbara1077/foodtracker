import Foundation

protocol MealRepository: Sendable {
    func meals(on day: Date, calendar: Calendar) async throws -> [MealRecord]
    func totals(on day: Date, calendar: Calendar) async throws -> DayNutritionTotals
    func save(_ meal: MealRecord) async throws
    func delete(id: UUID) async throws
    func meal(id: UUID) async throws -> MealRecord?
    /// Days in range that have at least one meal (for history dots).
    func daysWithMeals(from start: Date, to end: Date, calendar: Calendar) async throws -> Set<DateComponents>
    /// Per-day totals from `start` through `end` (inclusive start-of-day bounds).
    func dailyTotals(from start: Date, to end: Date, calendar: Calendar) async throws -> [(date: Date, totals: DayNutritionTotals)]
}

protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent)
}

enum AnalyticsEvent: Sendable, Equatable {
    case onboardingStarted
    case onboardingCompleted
    case scannerOpened
    case photoCaptured
    case scanStarted
    case scanSucceeded
    case scanFailed
    case scanRetried
    case scanCorrected
    case barcodeOpened
    case mealSaved
    case mealDeleted
    case paywallViewed
    case purchaseCompleted
    case purchaseRestored
    case cloudAIConsentAccepted
    case cloudAIConsentDeclined
    case dataExported
    case dataDeleted
    case iCloudSyncCompleted
    case day2Return
    case day7Return
    case daySummaryShared
}

struct SettingsStore: Sendable {}

struct NoOpAnalyticsClient: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
}
