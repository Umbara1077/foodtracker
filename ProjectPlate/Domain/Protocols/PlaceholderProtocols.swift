import Foundation

protocol MealRepository: Sendable {
    func meals(on day: Date, calendar: Calendar) async throws -> [MealSummary]
}

protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent)
}

enum AnalyticsEvent: Sendable {
    case onboardingStarted
    case scannerOpened
    case mealSaved
}

struct MealSummary: Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let eatenAt: Date
    let mealType: MealType
    let calories: Double
}

/// Placeholder repositories for Phase 0 — real SwiftData queries arrive in Phase 2.
struct InMemoryMealRepository: MealRepository {
    func meals(on day: Date, calendar: Calendar) async throws -> [MealSummary] {
        []
    }
}

struct SettingsStore: Sendable {
    var saveMealPhotos = true
    var onboardingComplete = false
    var cloudAIConsentVersion: String?
}

struct NoOpAnalyticsClient: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
}
