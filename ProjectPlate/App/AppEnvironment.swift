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
    var healthSync: any HealthSyncClient
    var diary: DiaryService
    var dataMaintenance: DataMaintenanceService
    var correctionStore: any CorrectionFeedbackStore
    var savedMeals: any SavedMealRepository
    var mealPlan: any MealPlanRepository
    var householdStore: any HouseholdStore
    var diarySync: DiarySyncCoordinator
    var subscriptions: any SubscriptionServicing
    var aiScanQuota: LocalAIScanQuotaStore
    var backendConfiguration: BackendConfiguration
    var scanQuota: ScanQuotaStore
    var settings: SettingsStore
    var analytics: any AnalyticsClient
    var crashReporter: any CrashReporting

    static func live(modelContainer: ModelContainer) -> AppEnvironment {
        let nutrition = LocalNutritionRepository()
        let backend = BackendConfiguration.load()
        let quota = ScanQuotaStore()
        let vision = makeVisionProvider(backend: backend, quota: quota)
        let meals = SwiftDataMealRepository(modelContainer: modelContainer)
        let profiles = SwiftDataProfileRepository(modelContainer: modelContainer)
        let weights = SwiftDataWeightRepository(modelContainer: modelContainer)
        let targets = SwiftDataTargetRepository(modelContainer: modelContainer)
        let health: any HealthSyncClient = HealthKitSyncClient()
        let savedMeals = SwiftDataSavedMealRepository(modelContainer: modelContainer)
        let mealPlan = UserDefaultsMealPlanRepository()
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: weights,
            profileRepository: profiles,
            health: health,
            savedMeals: savedMeals
        )
        let crashReporter = LoggingCrashReporter()
        let diarySync = DiarySyncCoordinator(
            mealRepository: meals,
            weightRepository: weights,
            profileRepository: profiles,
            targetRepository: targets,
            savedMealRepository: savedMeals,
            syncService: makeSyncService()
        )
        return AppEnvironment(
            mealRepository: meals,
            profileRepository: profiles,
            targetRepository: targets,
            weightRepository: weights,
            nutritionRepository: nutrition,
            mealAnalysisService: MealAnalysisService(
                visionProvider: vision,
                nutritionRepository: nutrition
            ),
            healthSync: health,
            diary: diary,
            dataMaintenance: DataMaintenanceService(
                mealRepository: meals,
                weightRepository: weights,
                profileRepository: profiles,
                targetRepository: targets,
                savedMealRepository: savedMeals,
                diarySync: diarySync
            ),
            correctionStore: LocalCorrectionFeedbackStore(),
            savedMeals: savedMeals,
            mealPlan: mealPlan,
            householdStore: UserDefaultsHouseholdStore(),
            diarySync: diarySync,
            subscriptions: StoreKitPurchaseManager(),
            aiScanQuota: LocalAIScanQuotaStore(dailyLimit: 3),
            backendConfiguration: backend,
            scanQuota: quota,
            settings: SettingsStore(),
            analytics: PrivacyAnalyticsClient(crashReporter: crashReporter),
            crashReporter: crashReporter
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
        let meals = InMemoryMealRepository(meals: [sampleMeal])
        let profiles = InMemoryProfileRepository(profile: profile)
        let weightRepo = InMemoryWeightRepository(entries: weights)
        let health = NoOpHealthSyncClient()
        let savedMeals = InMemorySavedMealRepository(templates: [
            SavedMealTemplate(
                fingerprint: SavedMealTemplate.fingerprint(
                    title: sampleMeal.title,
                    nutrients: sampleMeal.nutrients
                ),
                title: sampleMeal.title,
                mealType: sampleMeal.mealType,
                nutrients: sampleMeal.nutrients,
                useCount: 4,
                lastUsedAt: .now
            ),
        ])
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: weightRepo,
            profileRepository: profiles,
            health: health,
            savedMeals: savedMeals
        )
        let targets = InMemoryTargetRepository(targets: [target])
        let crashReporter = LoggingCrashReporter()
        let diarySync = DiarySyncCoordinator(
            mealRepository: meals,
            weightRepository: weightRepo,
            profileRepository: profiles,
            targetRepository: targets,
            savedMealRepository: savedMeals,
            syncService: InMemorySyncService()
        )
        return AppEnvironment(
            mealRepository: meals,
            profileRepository: profiles,
            targetRepository: targets,
            weightRepository: weightRepo,
            nutritionRepository: nutrition,
            mealAnalysisService: MealAnalysisService(
                visionProvider: MockMealVisionProvider(fixture: .chickenRiceBowl, delayNanoseconds: 0),
                nutritionRepository: nutrition
            ),
            healthSync: health,
            diary: diary,
            dataMaintenance: DataMaintenanceService(
                mealRepository: meals,
                weightRepository: weightRepo,
                profileRepository: profiles,
                targetRepository: targets,
                savedMealRepository: savedMeals,
                diarySync: diarySync
            ),
            correctionStore: LocalCorrectionFeedbackStore(
                defaults: UserDefaults(suiteName: "plate.preview.corrections") ?? .standard
            ),
            savedMeals: savedMeals,
            mealPlan: InMemoryMealPlanRepository(items: [
                PlannedMeal(
                    dayStart: today,
                    mealType: .dinner,
                    title: "Salmon + greens"
                ),
            ]),
            householdStore: UserDefaultsHouseholdStore(
                defaults: UserDefaults(suiteName: "plate.preview.household") ?? .standard
            ),
            diarySync: diarySync,
            subscriptions: MockPurchaseManager(),
            aiScanQuota: LocalAIScanQuotaStore(dailyLimit: 3),
            backendConfiguration: backend,
            scanQuota: quota,
            settings: SettingsStore(),
            analytics: PrivacyAnalyticsClient(crashReporter: crashReporter),
            crashReporter: crashReporter
        )
    }

    /// XCTest host apps are unsigned and lack the CloudKit entitlement; constructing
    /// `CKContainer` traps. Use in-memory sync under tests; CloudKit only in real installs.
    private static func makeSyncService() -> any SyncService {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return InMemorySyncService()
        }
        return CloudKitSyncService()
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
