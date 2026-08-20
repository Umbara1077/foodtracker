import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 20 — iCloud sync records & merge")
struct CloudSyncTests {
    @Test("Preference defaults off and round-trips")
    func preference() {
        let defaults = UserDefaults(suiteName: "test.plate.sync.\(UUID().uuidString)")!
        #expect(!CloudSyncPreference.isEnabled(defaults: defaults))
        CloudSyncPreference.setEnabled(true, defaults: defaults)
        #expect(CloudSyncPreference.isEnabled(defaults: defaults))
        CloudSyncPreference.setLastSyncDate(Date(timeIntervalSince1970: 1_700_000_000), defaults: defaults)
        #expect(CloudSyncPreference.lastSyncDate(defaults: defaults) == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("Merge prefers newer remote")
    func mergePolicy() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        #expect(SyncMergePolicy.shouldApplyRemote(localUpdatedAt: nil, remoteUpdatedAt: newer))
        #expect(SyncMergePolicy.shouldApplyRemote(localUpdatedAt: older, remoteUpdatedAt: newer))
        #expect(SyncMergePolicy.shouldApplyRemote(localUpdatedAt: newer, remoteUpdatedAt: newer))
        #expect(!SyncMergePolicy.shouldApplyRemote(localUpdatedAt: newer, remoteUpdatedAt: older))
    }

    @Test("Meal sync record round-trips payload")
    func mealCodec() throws {
        let meal = MealRecord(
            mealType: .lunch,
            title: "Bowl",
            nutrients: NutrientSet(calories: 500, protein: 40, carbs: 45, fat: 12),
            inputMethod: .quickAdd
        )
        let record = try SyncRecordCodec.makeMeal(meal)
        #expect(record.kind == .meal)
        #expect(record.id == meal.id)
        let decoded = try SyncRecordCodec.decodePayload(MealRecord.self, from: record.payloadJSON)
        #expect(decoded == meal)
    }

    @Test("Coordinator uploads local meals and applies newer remote")
    func coordinatorRoundTrip() async throws {
        let defaults = UserDefaults(suiteName: "test.plate.sync.coord.\(UUID().uuidString)")!
        CloudSyncPreference.setEnabled(true, defaults: defaults)

        let localMeal = MealRecord(
            id: UUID(),
            mealType: .breakfast,
            title: "Local oats",
            nutrients: NutrientSet(calories: 320, protein: 12, carbs: 50, fat: 8),
            inputMethod: .quickAdd,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let remoteMeal = MealRecord(
            id: localMeal.id,
            mealType: .breakfast,
            title: "Remote oats",
            nutrients: NutrientSet(calories: 340, protein: 14, carbs: 52, fat: 9),
            inputMethod: .quickAdd,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let meals = InMemoryMealRepository(meals: [localMeal])
        let profiles = InMemoryProfileRepository(profile: nil)
        let weights = InMemoryWeightRepository()
        let targets = InMemoryTargetRepository()
        let saved = InMemorySavedMealRepository()
        let remote = try SyncRecordCodec.makeMeal(remoteMeal)
        let sync = InMemorySyncService()
        await sync.seed([remote])

        let coordinator = DiarySyncCoordinator(
            mealRepository: meals,
            weightRepository: weights,
            profileRepository: profiles,
            targetRepository: targets,
            savedMealRepository: saved,
            syncService: sync,
            defaults: defaults
        )

        try await coordinator.syncIfEnabled()

        let stored = try await meals.meal(id: localMeal.id)
        #expect(stored?.title == "Remote oats")
        #expect(stored?.nutrients.calories == 340)

        let uploaded = await sync.storedRecords()
        #expect(uploaded.contains(where: { $0.id == localMeal.id && $0.kind == .meal }))
        #expect(CloudSyncPreference.lastSyncDate(defaults: defaults) != nil)
    }

    @Test("CloudKit record mapping preserves fields")
    func cloudKitMapping() throws {
        let meal = MealRecord(
            mealType: .dinner,
            title: "Pasta",
            nutrients: NutrientSet(calories: 700, protein: 25, carbs: 90, fat: 22),
            inputMethod: .photoScan
        )
        let syncRecord = try SyncRecordCodec.makeMeal(meal)
        let ck = CloudKitSyncService.makeCKRecord(from: syncRecord)
        let roundTrip = CloudKitSyncService.makeSyncRecord(from: ck)
        #expect(roundTrip?.id == syncRecord.id)
        #expect(roundTrip?.kind == .meal)
        #expect(roundTrip?.updatedAt == syncRecord.updatedAt)
        #expect(roundTrip?.payloadJSON == syncRecord.payloadJSON)
        #expect(roundTrip?.deleted == false)
    }
}
