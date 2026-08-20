import Foundation
import SwiftData

@ModelActor
actor SwiftDataSavedMealRepository: SavedMealRepository {
    func recordUsage(of meal: MealRecord) async throws {
        let key = SavedMealTemplate.fingerprint(for: meal)
        let descriptor = FetchDescriptor<SavedMealEntity>(
            predicate: #Predicate { $0.fingerprint == key }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.title = meal.title
            existing.mealTypeRaw = meal.mealType.rawValue
            existing.calories = meal.nutrients.calories
            existing.protein = meal.nutrients.protein
            existing.carbs = meal.nutrients.carbs
            existing.fat = meal.nutrients.fat
            existing.useCount += 1
            existing.lastUsedAt = .now
        } else {
            let template = SavedMealTemplate(
                fingerprint: key,
                title: meal.title,
                mealType: meal.mealType,
                nutrients: meal.nutrients,
                useCount: 1,
                lastUsedAt: .now
            )
            modelContext.insert(SavedMealEntity(from: template))
        }
        try modelContext.save()
    }

    func frequent(limit: Int) async throws -> [SavedMealTemplate] {
        FrequentMealRanking.ranked(try await all(), limit: limit)
    }

    func all() async throws -> [SavedMealTemplate] {
        let descriptor = FetchDescriptor<SavedMealEntity>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.asDomain() }
    }

    func clear() async throws {
        let descriptor = FetchDescriptor<SavedMealEntity>()
        for entity in try modelContext.fetch(descriptor) {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }
}

actor InMemorySavedMealRepository: SavedMealRepository {
    private var templates: [SavedMealTemplate]

    init(templates: [SavedMealTemplate] = []) {
        self.templates = templates
    }

    func recordUsage(of meal: MealRecord) async throws {
        let key = SavedMealTemplate.fingerprint(for: meal)
        if let index = templates.firstIndex(where: { $0.fingerprint == key }) {
            templates[index].title = meal.title
            templates[index].mealType = meal.mealType
            templates[index].nutrients = meal.nutrients
            templates[index].useCount += 1
            templates[index].lastUsedAt = .now
        } else {
            templates.append(
                SavedMealTemplate(
                    fingerprint: key,
                    title: meal.title,
                    mealType: meal.mealType,
                    nutrients: meal.nutrients,
                    useCount: 1,
                    lastUsedAt: .now
                )
            )
        }
    }

    func frequent(limit: Int) async throws -> [SavedMealTemplate] {
        FrequentMealRanking.ranked(templates, limit: limit)
    }

    func all() async throws -> [SavedMealTemplate] {
        templates
    }

    func clear() async throws {
        templates.removeAll()
    }
}
