import Foundation

/// JSON file persistence for the Xcode 14.2 / iOS 16 legacy build (replaces SwiftData).
enum JSONFileStore {
    static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("ProjectPlate", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(named filename: String) throws -> URL {
        try applicationSupportDirectory().appendingPathComponent(filename)
    }

    static func load<T: Decodable>(_ type: T.Type, from filename: String, default defaultValue: T) -> T {
        guard
            let url = try? fileURL(named: filename),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(type, from: data)
        else {
            return defaultValue
        }
        return decoded
    }

    static func save<T: Encodable>(_ value: T, to filename: String) throws {
        let url = try fileURL(named: filename)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }
}

#if LEGACY_BUILD

actor FileMealRepository: MealRepository {
    private static let filename = "meals.json"
    private var meals: [MealRecord]

    init() {
        meals = JSONFileStore.load([MealRecord].self, from: Self.filename, default: [])
    }

    private func persist() throws {
        try JSONFileStore.save(meals, to: Self.filename)
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
        try persist()
    }

    func delete(id: UUID) async throws {
        meals.removeAll { $0.id == id }
        try persist()
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

    func dailyTotals(from start: Date, to end: Date, calendar: Calendar) async throws -> [(date: Date, totals: DayNutritionTotals)] {
        var result: [(date: Date, totals: DayNutritionTotals)] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            let dayTotals = try await totals(on: cursor, calendar: calendar)
            result.append((cursor, dayTotals))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}

private struct ProfileStore: Codable {
    var profile: UserProfile?
}

actor FileProfileRepository: ProfileRepository {
    private static let filename = "profile.json"
    private var profile: UserProfile?

    init() {
        let store = JSONFileStore.load(ProfileStore.self, from: Self.filename, default: ProfileStore(profile: nil))
        profile = store.profile
    }

    private func persist() throws {
        try JSONFileStore.save(ProfileStore(profile: profile), to: Self.filename)
    }

    func loadProfile() async throws -> UserProfile? { profile }

    func saveProfile(_ profile: UserProfile) async throws {
        self.profile = profile
        try persist()
    }
}

actor FileTargetRepository: TargetRepository {
    private static let filename = "targets.json"
    private var targets: [NutritionTargetSnapshot]

    init() {
        targets = JSONFileStore.load([NutritionTargetSnapshot].self, from: Self.filename, default: [])
    }

    private func persist() throws {
        try JSONFileStore.save(targets, to: Self.filename)
    }

    func currentTarget(on date: Date) async throws -> NutritionTargetSnapshot? {
        targets
            .sorted { $0.effectiveDate > $1.effectiveDate }
            .first { $0.effectiveDate <= date } ?? targets.first
    }

    func saveTarget(_ snapshot: NutritionTargetSnapshot) async throws {
        if let index = targets.firstIndex(where: { $0.id == snapshot.id }) {
            targets[index] = snapshot
        } else {
            targets.append(snapshot)
        }
        try persist()
    }

    func allTargets() async throws -> [NutritionTargetSnapshot] {
        targets.sorted { $0.effectiveDate > $1.effectiveDate }
    }
}

actor FileWeightRepository: WeightRepository {
    private static let filename = "weights.json"
    private var entries: [WeightEntry]

    init() {
        entries = JSONFileStore.load([WeightEntry].self, from: Self.filename, default: [])
    }

    private func persist() throws {
        try JSONFileStore.save(entries, to: Self.filename)
    }

    func entries(from start: Date, to end: Date) async throws -> [WeightEntry] {
        entries
            .filter { $0.recordedAt >= start && $0.recordedAt <= end }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func latest() async throws -> WeightEntry? {
        entries.max(by: { $0.recordedAt < $1.recordedAt })
    }

    func save(_ entry: WeightEntry) async throws {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        try persist()
    }

    func delete(id: UUID) async throws {
        entries.removeAll { $0.id == id }
        try persist()
    }
}

actor FileSavedMealRepository: SavedMealRepository {
    private static let filename = "saved-meals.json"
    private var templates: [SavedMealTemplate]

    init() {
        templates = JSONFileStore.load([SavedMealTemplate].self, from: Self.filename, default: [])
    }

    private func persist() throws {
        try JSONFileStore.save(templates, to: Self.filename)
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
        try persist()
    }

    func frequent(limit: Int) async throws -> [SavedMealTemplate] {
        FrequentMealRanking.ranked(templates, limit: limit)
    }

    func all() async throws -> [SavedMealTemplate] {
        templates
    }

    func upsert(_ template: SavedMealTemplate) async throws {
        if let index = templates.firstIndex(where: { $0.id == template.id || $0.fingerprint == template.fingerprint }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        try persist()
    }

    func delete(id: UUID) async throws {
        templates.removeAll { $0.id == id }
        try persist()
    }

    func clear() async throws {
        templates.removeAll()
        try persist()
    }
}

#endif
