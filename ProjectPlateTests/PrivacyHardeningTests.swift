import Testing
@testable import ProjectPlate
import Foundation

struct PrivacyHardeningTests {
    @Test("Export payload encodes meals and profile without throwing")
    func exportJSON() async throws {
        var profile = UserProfile.blank
        profile.onboardingComplete = true
        profile.cloudAIConsentVersion = PrivacyConstants.cloudAIConsentVersion
        let meals = InMemoryMealRepository(meals: [
            MealRecord(
                mealType: .lunch,
                title: "Export meal",
                nutrients: NutrientSet(calories: 400, protein: 30, carbs: 20, fat: 10),
                inputMethod: .quickAdd
            ),
        ])
        let service = DataMaintenanceService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(entries: [
                WeightEntry(kilograms: 70),
            ]),
            profileRepository: InMemoryProfileRepository(profile: profile),
            targetRepository: InMemoryTargetRepository(targets: [
                NutritionTargetSnapshot(
                    calories: 2000,
                    proteinGrams: 150,
                    carbGrams: 200,
                    fatGrams: 60,
                    source: .manual
                ),
            ])
        )
        let data = try await service.exportJSON()
        #expect(!data.isEmpty)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiaryExportPayload.self, from: data)
        #expect(decoded.meals.count == 1)
        #expect(decoded.consentVersion == PrivacyConstants.cloudAIConsentVersion)
    }

    @Test("Delete all local data clears meals and resets profile")
    func deleteAll() async throws {
        var profile = UserProfile.blank
        profile.onboardingComplete = true
        let meals = InMemoryMealRepository(meals: [
            MealRecord(
                mealType: .snack,
                title: "Gone",
                nutrients: NutrientSet(calories: 100, protein: 1, carbs: 1, fat: 1),
                inputMethod: .quickAdd
            ),
        ])
        let profiles = InMemoryProfileRepository(profile: profile)
        let service = DataMaintenanceService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: profiles,
            targetRepository: InMemoryTargetRepository()
        )
        try await service.deleteAllLocalData()
        let remaining = try await meals.meals(on: .now, calendar: .current)
        #expect(remaining.isEmpty)
        let reset = try await profiles.loadProfile()
        #expect(reset?.onboardingComplete == false)
    }

    @Test("Consent version constant is non-empty")
    func consentVersion() {
        #expect(!PrivacyConstants.cloudAIConsentVersion.isEmpty)
    }
}
