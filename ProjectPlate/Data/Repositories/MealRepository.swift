import Foundation
import SwiftData

@ModelActor
actor SwiftDataMealRepository: MealRepository {
    func meals(on day: Date, calendar: Calendar) async throws -> [MealRecord] {
        let start = DayBoundary.start(of: day, calendar: calendar)
        let end = DayBoundary.end(of: day, calendar: calendar)
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { meal in
                meal.eatenAt >= start && meal.eatenAt < end
            },
            sortBy: [SortDescriptor(\.eatenAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.asDomain() }
    }

    func totals(on day: Date, calendar: Calendar) async throws -> DayNutritionTotals {
        let list = try await meals(on: day, calendar: calendar)
        let nutrients = list.reduce(NutrientSet.zero) { $0 + $1.nutrients }
        return DayNutritionTotals(nutrients: nutrients, mealCount: list.count)
    }

    func save(_ meal: MealRecord) async throws {
        let mealID = meal.id
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == mealID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(meal)
        } else {
            modelContext.insert(MealEntity(from: meal))
        }
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        let mealID = id
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == mealID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    func meal(id: UUID) async throws -> MealRecord? {
        let mealID = id
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { $0.id == mealID }
        )
        return try modelContext.fetch(descriptor).first?.asDomain()
    }

    func daysWithMeals(from start: Date, to end: Date, calendar: Calendar) async throws -> Set<DateComponents> {
        let descriptor = FetchDescriptor<MealEntity>(
            predicate: #Predicate { meal in
                meal.eatenAt >= start && meal.eatenAt < end
            }
        )
        let meals = try modelContext.fetch(descriptor)
        var days: Set<DateComponents> = []
        for meal in meals {
            days.insert(calendar.dateComponents([.year, .month, .day], from: meal.eatenAt))
        }
        return days
    }
}

actor InMemoryMealRepository: MealRepository {
    private var meals: [MealRecord]

    init(meals: [MealRecord] = []) {
        self.meals = meals
    }

    func meals(on day: Date, calendar: Calendar) async throws -> [MealRecord] {
        meals
            .filter { DayBoundary.contains($0.eatenAt, day: day, calendar: calendar) }
            .sorted { $0.eatenAt < $1.eatenAt }
    }

    func totals(on day: Date, calendar: Calendar) async throws -> DayNutritionTotals {
        let list = try await meals(on: day, calendar: calendar)
        let nutrients = list.reduce(NutrientSet.zero) { $0 + $1.nutrients }
        return DayNutritionTotals(nutrients: nutrients, mealCount: list.count)
    }

    func save(_ meal: MealRecord) async throws {
        if let idx = meals.firstIndex(where: { $0.id == meal.id }) {
            meals[idx] = meal
        } else {
            meals.append(meal)
        }
    }

    func delete(id: UUID) async throws {
        meals.removeAll { $0.id == id }
    }

    func meal(id: UUID) async throws -> MealRecord? {
        meals.first { $0.id == id }
    }

    func daysWithMeals(from start: Date, to end: Date, calendar: Calendar) async throws -> Set<DateComponents> {
        var days: Set<DateComponents> = []
        for meal in meals where meal.eatenAt >= start && meal.eatenAt < end {
            days.insert(calendar.dateComponents([.year, .month, .day], from: meal.eatenAt))
        }
        return days
    }
}
