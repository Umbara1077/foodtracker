import Foundation

actor UserDefaultsMealPlanRepository: MealPlanRepository {
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "plate.mealPlan.items") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func plans(from start: Date, to end: Date, calendar: Calendar) async throws -> [PlannedMeal] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return MealPlanMath.sorted(
            load().filter { plan in
                let day = calendar.startOfDay(for: plan.dayStart)
                return day >= startDay && day <= endDay
            }
        )
    }

    func plans(on day: Date, calendar: Calendar) async throws -> [PlannedMeal] {
        let target = calendar.startOfDay(for: day)
        return MealPlanMath.sorted(
            load().filter { calendar.isDate($0.dayStart, inSameDayAs: target) }
        )
    }

    func upsert(_ plan: PlannedMeal) async throws {
        var items = load()
        var copy = plan
        copy.dayStart = Calendar.current.startOfDay(for: plan.dayStart)
        if let index = items.firstIndex(where: { $0.id == copy.id }) {
            items[index] = copy
        } else {
            items.append(copy)
        }
        save(items)
    }

    func delete(id: UUID) async throws {
        var items = load()
        items.removeAll { $0.id == id }
        save(items)
    }

    func clear() async throws {
        save([])
    }

    private func load() -> [PlannedMeal] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([PlannedMeal].self, from: data)) ?? []
    }

    private func save(_ items: [PlannedMeal]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

actor InMemoryMealPlanRepository: MealPlanRepository {
    private var items: [PlannedMeal]

    init(items: [PlannedMeal] = []) {
        self.items = items
    }

    func plans(from start: Date, to end: Date, calendar: Calendar) async throws -> [PlannedMeal] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return MealPlanMath.sorted(
            items.filter { plan in
                let day = calendar.startOfDay(for: plan.dayStart)
                return day >= startDay && day <= endDay
            }
        )
    }

    func plans(on day: Date, calendar: Calendar) async throws -> [PlannedMeal] {
        let target = calendar.startOfDay(for: day)
        return MealPlanMath.sorted(
            items.filter { calendar.isDate($0.dayStart, inSameDayAs: target) }
        )
    }

    func upsert(_ plan: PlannedMeal) async throws {
        var copy = plan
        copy.dayStart = Calendar.current.startOfDay(for: plan.dayStart)
        if let index = items.firstIndex(where: { $0.id == copy.id }) {
            items[index] = copy
        } else {
            items.append(copy)
        }
    }

    func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    func clear() async throws {
        items.removeAll()
    }
}
