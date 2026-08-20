import Foundation
import SwiftData
import SwiftUI

/// Composition root for feature ViewModels. Concrete services are swapped for mocks in previews/tests.
struct AppEnvironment: Sendable {
    var mealRepository: any MealRepository
    var profileRepository: any ProfileRepository
    var targetRepository: any TargetRepository
    var settings: SettingsStore
    var analytics: any AnalyticsClient

    static func live(modelContainer: ModelContainer) -> AppEnvironment {
        AppEnvironment(
            mealRepository: InMemoryMealRepository(),
            profileRepository: SwiftDataProfileRepository(modelContainer: modelContainer),
            targetRepository: SwiftDataTargetRepository(modelContainer: modelContainer),
            settings: SettingsStore(),
            analytics: NoOpAnalyticsClient()
        )
    }

    static var preview: AppEnvironment {
        let target = NutritionTargetSnapshot(
            calories: 2180,
            proteinGrams: 136,
            carbGrams: 245,
            fatGrams: 73,
            source: .onboardingEstimate
        )
        var profile = UserProfile.blank
        profile.onboardingComplete = true
        profile.goalType = .maintainWeight
        return AppEnvironment(
            mealRepository: InMemoryMealRepository(),
            profileRepository: InMemoryProfileRepository(profile: profile),
            targetRepository: InMemoryTargetRepository(targets: [target]),
            settings: SettingsStore(),
            analytics: NoOpAnalyticsClient()
        )
    }
}

private enum AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .preview
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
