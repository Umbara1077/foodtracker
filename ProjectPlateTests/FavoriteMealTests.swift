import Foundation
import Testing
@testable import ProjectPlate

@Suite("V1.1 — Frequent / saved meals")
struct FavoriteMealTests {
    @Test("Fingerprint normalizes title and rounds calories")
    func fingerprint() {
        let a = SavedMealTemplate.fingerprint(
            title: "  Oatmeal Bowl ",
            nutrients: NutrientSet(calories: 312, protein: 12.4, carbs: 40.2, fat: 8.6)
        )
        let b = SavedMealTemplate.fingerprint(
            title: "oatmeal bowl",
            nutrients: NutrientSet(calories: 314, protein: 12.4, carbs: 40.2, fat: 8.6)
        )
        #expect(a == b)
        #expect(a.hasPrefix("oatmeal bowl|310|"))
    }

    @Test("Ranking prefers higher use count then recency")
    func ranking() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let templates = [
            SavedMealTemplate(
                fingerprint: "a",
                title: "A",
                mealType: .lunch,
                nutrients: NutrientSet(calories: 400, protein: 30, carbs: 20, fat: 10),
                useCount: 2,
                lastUsedAt: now.addingTimeInterval(-10 * 86_400)
            ),
            SavedMealTemplate(
                fingerprint: "b",
                title: "B",
                mealType: .dinner,
                nutrients: NutrientSet(calories: 600, protein: 40, carbs: 50, fat: 20),
                useCount: 5,
                lastUsedAt: now.addingTimeInterval(-2 * 86_400)
            ),
            SavedMealTemplate(
                fingerprint: "c",
                title: "C",
                mealType: .snack,
                nutrients: NutrientSet(calories: 150, protein: 5, carbs: 10, fat: 5),
                useCount: 1,
                lastUsedAt: now
            ),
        ]
        let ranked = FrequentMealRanking.ranked(templates, now: now, limit: 5)
        #expect(ranked.map(\.title) == ["B", "A"])
        #expect(!ranked.contains(where: { $0.title == "C" }))
    }

    @Test("Recording usage increments and frequent appears after two logs")
    func repositoryUsage() async throws {
        let repo = InMemorySavedMealRepository()
        let meal = MealRecord(
            mealType: .breakfast,
            title: "Eggs",
            nutrients: NutrientSet(calories: 220, protein: 18, carbs: 2, fat: 14),
            inputMethod: .quickAdd
        )
        try await repo.recordUsage(of: meal)
        #expect(try await repo.frequent(limit: 5).isEmpty)

        try await repo.recordUsage(of: meal)
        let frequent = try await repo.frequent(limit: 5)
        #expect(frequent.count == 1)
        #expect(frequent[0].useCount == 2)
        #expect(frequent[0].title == "Eggs")
    }

    @Test("Diary save records frequent template")
    func diaryRecordsUsage() async throws {
        let saved = InMemorySavedMealRepository()
        let diary = DiaryService(
            mealRepository: InMemoryMealRepository(),
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: UserProfile.blank),
            health: NoOpHealthSyncClient(),
            savedMeals: saved
        )
        let meal = MealRecord(
            mealType: .lunch,
            title: "Chicken bowl",
            nutrients: NutrientSet(calories: 620, protein: 48, carbs: 55, fat: 18),
            inputMethod: .photoScan
        )
        try await diary.saveMeal(meal)
        try await diary.saveMeal(meal.makeDuplicateForToday())
        let frequent = try await saved.frequent(limit: 3)
        #expect(frequent.count == 1)
        #expect(frequent[0].useCount == 2)
    }

    @Test("Delete all clears saved meals")
    func deleteClearsSaved() async throws {
        let saved = InMemorySavedMealRepository()
        let meal = MealRecord(
            mealType: .snack,
            title: "Yogurt",
            nutrients: NutrientSet(calories: 150, protein: 15, carbs: 10, fat: 3),
            inputMethod: .quickAdd
        )
        try await saved.recordUsage(of: meal)
        try await saved.recordUsage(of: meal)
        let service = DataMaintenanceService(
            mealRepository: InMemoryMealRepository(),
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: UserProfile.blank),
            targetRepository: InMemoryTargetRepository(),
            savedMealRepository: saved
        )
        try await service.deleteAllLocalData()
        #expect(try await saved.all().isEmpty)
    }
}

private extension MealRecord {
    func makeDuplicateForToday() -> MealRecord {
        var copy = self
        copy.id = UUID()
        copy.eatenAt = .now
        copy.inputMethod = .duplicated
        copy.healthKitAnchors = nil
        copy.createdAt = .now
        copy.updatedAt = .now
        return copy
    }
}
