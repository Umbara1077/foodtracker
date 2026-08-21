import Testing
@testable import ProjectPlate
import Foundation

final class RecordingHealthSyncClient: HealthSyncClient, @unchecked Sendable {
    var isDataAvailable: Bool = true
    var status: HealthAuthStatus = .sharingAuthorized
    private let lock = NSLock()
    private var _mealWrites: [MealRecord] = []
    private var _mealDeletes: [MealHealthKitAnchors] = []
    private var _weightWrites: [WeightEntry] = []
    var remoteWeights: [WeightEntry] = []

    var mealWrites: [MealRecord] {
        lock.lock(); defer { lock.unlock() }
        return _mealWrites
    }

    var mealDeletes: [MealHealthKitAnchors] {
        lock.lock(); defer { lock.unlock() }
        return _mealDeletes
    }

    func authorizationStatus() -> HealthAuthStatus { status }

    func requestAuthorization() async throws -> Bool { true }

    func writeMealNutrition(_ meal: MealRecord) async throws -> MealHealthKitAnchors {
        lock.lock(); _mealWrites.append(meal); lock.unlock()
        return MealHealthKitAnchors(
            energyUUID: UUID().uuidString,
            proteinUUID: UUID().uuidString,
            carbsUUID: UUID().uuidString,
            fatUUID: UUID().uuidString
        )
    }

    func deleteMealNutrition(_ anchors: MealHealthKitAnchors) async throws {
        lock.lock(); _mealDeletes.append(anchors); lock.unlock()
    }

    func writeBodyMass(_ entry: WeightEntry) async throws -> String? {
        lock.lock(); _weightWrites.append(entry); lock.unlock()
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
            health: health,
            savedMeals: InMemorySavedMealRepository()
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
        #expect(health.mealWrites.count == 1)
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
            health: health,
            savedMeals: InMemorySavedMealRepository()
        )
        try await diary.saveMeal(
            MealRecord(
                mealType: .snack,
                title: "Skip",
                nutrients: NutrientSet(calories: 100, protein: 1, carbs: 1, fat: 1),
                inputMethod: .quickAdd
            )
        )
        #expect(health.mealWrites.isEmpty)
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
        health.remoteWeights = [
            WeightEntry(kilograms: 70, source: .healthKit, healthKitUUID: existingUUID),
            WeightEntry(kilograms: 71, source: .healthKit, healthKitUUID: "CCCC-DDDD"),
        ]
        let diary = DiaryService(
            mealRepository: InMemoryMealRepository(),
            weightRepository: weights,
            profileRepository: InMemoryProfileRepository(profile: profile),
            health: health,
            savedMeals: InMemorySavedMealRepository()
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
            health: health,
            savedMeals: InMemorySavedMealRepository()
        )
        try await diary.deleteMeal(meal)
        let remaining = try await meals.meals(on: .now, calendar: .current)
        #expect(remaining.isEmpty)
        #expect(health.mealDeletes.count == 1)
    }
}
