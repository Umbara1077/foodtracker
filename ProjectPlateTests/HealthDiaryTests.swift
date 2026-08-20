import Testing
@testable import ProjectPlate
import Foundation

actor RecordingHealthSyncClient: HealthSyncClient {
    var isDataAvailable: Bool = true
    var status: HealthAuthStatus = .sharingAuthorized
    var mealWrites: [MealRecord] = []
    var mealDeletes: [MealHealthKitAnchors] = []
    var weightWrites: [WeightEntry] = []
    var remoteWeights: [WeightEntry] = []

    func authorizationStatus() -> HealthAuthStatus { status }

    func requestAuthorization() async throws -> Bool { true }

    func writeMealNutrition(_ meal: MealRecord) async throws -> MealHealthKitAnchors {
        mealWrites.append(meal)
        return MealHealthKitAnchors(
            energyUUID: UUID().uuidString,
            proteinUUID: UUID().uuidString,
            carbsUUID: UUID().uuidString,
            fatUUID: UUID().uuidString
        )
    }

    func deleteMealNutrition(_ anchors: MealHealthKitAnchors) async throws {
        mealDeletes.append(anchors)
    }

    func writeBodyMass(_ entry: WeightEntry) async throws -> String? {
        weightWrites.append(entry)
        return UUID().uuidString
    }

    func readBodyMass(from start: Date, to end: Date) async throws -> [WeightEntry] {
        remoteWeights.filter { $0.recordedAt >= start && $0.recordedAt <= end }
    }
}

struct HealthDiaryTests {
    @Test("Diary writes Health anchors when sync enabled")
    func saveMealWritesHealth() async throws {
        var profile = UserProfile.blank
        profile.healthKitEnabled = true
        let meals = InMemoryMealRepository()
        let health = RecordingHealthSyncClient()
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: profile),
            health: health
        )
        let meal = MealRecord(
            mealType: .lunch,
            title: "Test",
            nutrients: NutrientSet(calories: 500, protein: 30, carbs: 40, fat: 10),
            inputMethod: .quickAdd
        )
        try await diary.saveMeal(meal)
        let stored = try await meals.meals(on: .now, calendar: .current)
        #expect(stored.count == 1)
        #expect(stored.first?.healthKitAnchors?.energyUUID != nil)
        let writes = await health.mealWrites
        #expect(writes.count == 1)
    }

    @Test("Diary skips Health when sync disabled")
    func saveMealSkipsHealth() async throws {
        var profile = UserProfile.blank
        profile.healthKitEnabled = false
        let health = RecordingHealthSyncClient()
        let diary = DiaryService(
            mealRepository: InMemoryMealRepository(),
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: profile),
            health: health
        )
        try await diary.saveMeal(
            MealRecord(
                mealType: .snack,
                title: "Skip",
                nutrients: NutrientSet(calories: 100, protein: 1, carbs: 1, fat: 1),
                inputMethod: .quickAdd
            )
        )
        let writes = await health.mealWrites
        #expect(writes.isEmpty)
    }

    @Test("Import dedupes by healthKitUUID")
    func importDedupes() async throws {
        var profile = UserProfile.blank
        profile.healthKitEnabled = true
        let existingUUID = "AAAA-BBBB"
        let weights = InMemoryWeightRepository(entries: [
            WeightEntry(kilograms: 70, source: .healthKit, healthKitUUID: existingUUID),
        ])
        let health = RecordingHealthSyncClient()
        await health.setRemote([
            WeightEntry(kilograms: 70, source: .healthKit, healthKitUUID: existingUUID),
            WeightEntry(kilograms: 71, source: .healthKit, healthKitUUID: "CCCC-DDDD"),
        ])
        let diary = DiaryService(
            mealRepository: InMemoryMealRepository(),
            weightRepository: weights,
            profileRepository: InMemoryProfileRepository(profile: profile),
            health: health
        )
        let imported = try await diary.importWeightsFromHealth(
            from: Date().addingTimeInterval(-86_400),
            to: Date().addingTimeInterval(86_400)
        )
        #expect(imported == 1)
    }

    @Test("Delete meal removes Health samples when anchors exist")
    func deleteRemovesHealth() async throws {
        var profile = UserProfile.blank
        profile.healthKitEnabled = true
        let anchors = MealHealthKitAnchors(energyUUID: "E1", proteinUUID: "P1", carbsUUID: nil, fatUUID: nil)
        let meal = MealRecord(
            mealType: .dinner,
            title: "Delete me",
            nutrients: NutrientSet(calories: 600, protein: 40, carbs: 50, fat: 20),
            inputMethod: .quickAdd,
            healthKitAnchors: anchors
        )
        let meals = InMemoryMealRepository(meals: [meal])
        let health = RecordingHealthSyncClient()
        let diary = DiaryService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: profile),
            health: health
        )
        try await diary.deleteMeal(meal)
        let remaining = try await meals.meals(on: .now, calendar: .current)
        #expect(remaining.isEmpty)
        let deletes = await health.mealDeletes
        #expect(deletes.count == 1)
    }
}

private extension RecordingHealthSyncClient {
    func setRemote(_ entries: [WeightEntry]) {
        remoteWeights = entries
    }
}
