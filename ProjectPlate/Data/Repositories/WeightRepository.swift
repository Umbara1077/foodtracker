import Foundation
import SwiftData

@ModelActor
actor SwiftDataWeightRepository: WeightRepository {
    func entries(from start: Date, to end: Date) async throws -> [WeightEntry] {
        let descriptor = FetchDescriptor<WeightEntryEntity>(
            predicate: #Predicate { row in
                row.recordedAt >= start && row.recordedAt <= end
            },
            sortBy: [SortDescriptor(\.recordedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.asDomain() }
    }

    func latest() async throws -> WeightEntry? {
        let descriptor = FetchDescriptor<WeightEntryEntity>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first?.asDomain()
    }

    func save(_ entry: WeightEntry) async throws {
        let entryID = entry.id
        let descriptor = FetchDescriptor<WeightEntryEntity>(
            predicate: #Predicate { $0.id == entryID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(entry)
        } else {
            modelContext.insert(WeightEntryEntity(from: entry))
        }
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        let entryID = id
        let descriptor = FetchDescriptor<WeightEntryEntity>(
            predicate: #Predicate { $0.id == entryID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }
}

actor InMemoryWeightRepository: WeightRepository {
    private var entries: [WeightEntry]

    init(entries: [WeightEntry] = []) {
        self.entries = entries
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
    }

    func delete(id: UUID) async throws {
        entries.removeAll { $0.id == id }
    }
}
