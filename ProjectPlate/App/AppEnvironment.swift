import Foundation
import SwiftData
import SwiftUI

/// Composition root for feature ViewModels. Concrete services are swapped for mocks in previews/tests.
struct AppEnvironment: Sendable {
    var mealRepository: any MealRepository
    var profileRepository: any ProfileRepository
    var targetRepository: any TargetRepository
    var weightRepository: any WeightRepository
    var nutritionRepository: any NutritionRepository
    var mealAnalysisService: any MealAnalysisServing
    var backendConfiguration: BackendConfiguration
    var scanQuota: ScanQuotaStore
    var settings: SettingsStore
    var analytics: any AnalyticsClient

    static func live(modelContainer: ModelContainer) -> AppEnvironment {
        let nutrition = LocalNutritionRepository()
        let backend = BackendConfiguration.load()
        let quota = ScanQuotaStore()
        let vision = makeVisionProvider(backend: backend, quota: quota)
        return AppEnvironment(
            mealRepository: SwiftDataMealRepository(modelContainer: modelContainer),
            profileRepository: SwiftDataProfileRepository(modelContainer: modelContainer),
            targetRepository: SwiftDataTargetRepository(modelContainer: modelContainer),
            weightRepository: SwiftDataWeightRepository(modelContainer: modelContainer),
            nutritionRepository: nutrition,
            mealAnalysisService: MealAnalysisService(
                visionProvider: vision,
                nutritionRepository: nutrition
            ),
            backendConfiguration: backend,
            scanQuota: quota,
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
        profile.currentWeightKg = 72.4
        profile.unitSystem = .metric

        let sampleMeal = MealRecord(
            mealType: .lunch,
            title: "Chicken rice bowl",
            nutrients: NutrientSet(calories: 620, protein: 48, carbs: 55, fat: 18),
            inputMethod: .quickAdd
        )

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weights = [
            WeightEntry(recordedAt: calendar.date(byAdding: .day, value: -14, to: today)!, kilograms: 73.2),
            WeightEntry(recordedAt: calendar.date(byAdding: .day, value: -7, to: today)!, kilograms: 72.8),
            WeightEntry(recordedAt: today, kilograms: 72.4),
        ]

        let nutrition = LocalNutritionRepository()
        let backend = BackendConfiguration(baseURL: nil, appToken: nil, installID: "preview")
        let quota = ScanQuotaStore()
        return AppEnvironment(
            mealRepository: InMemoryMealRepository(meals: [sampleMeal]),
            profileRepository: InMemoryProfileRepository(profile: profile),
            targetRepository: InMemoryTargetRepository(targets: [target]),
            weightRepository: InMemoryWeightRepository(entries: weights),
            nutritionRepository: nutrition,
            mealAnalysisService: MealAnalysisService(
                visionProvider: MockMealVisionProvider(fixture: .chickenRiceBowl, delayNanoseconds: 0),
                nutritionRepository: nutrition
            ),
            backendConfiguration: backend,
            scanQuota: quota,
            settings: SettingsStore(),
            analytics: NoOpAnalyticsClient()
        )
    }

    private static func makeVisionProvider(
        backend: BackendConfiguration,
        quota: ScanQuotaStore
    ) -> any MealVisionProvider {
        let mock = MockMealVisionProvider(fixture: .chickenRiceBowl)
        guard backend.isCloudEnabled else { return mock }

        let managed = ManagedCloudVisionProvider(
            configuration: backend,
            onQuotaUpdate: { remaining, dailyLimit in
                quota.update(remaining: remaining, dailyLimit: dailyLimit)
            }
        )
        return MealVisionRouter(
            mockProvider: mock,
            managedProvider: managed,
            preferManaged: true
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
