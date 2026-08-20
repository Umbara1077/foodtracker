import Foundation
import SwiftData
import SwiftUI

/// Composition root for feature ViewModels. Concrete services are swapped for mocks in previews/tests.
struct AppEnvironment: Sendable {
    var mealRepository: any MealRepository
    var settings: SettingsStore
    var analytics: any AnalyticsClient

    static func live(modelContainer: ModelContainer) -> AppEnvironment {
        // ModelContainer is attached at the scene level; meal queries land in Phase 2.
        _ = modelContainer
        return AppEnvironment(
            mealRepository: InMemoryMealRepository(),
            settings: SettingsStore(),
            analytics: NoOpAnalyticsClient()
        )
    }

    static var preview: AppEnvironment {
        AppEnvironment(
            mealRepository: InMemoryMealRepository(),
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
