import Foundation

/// In-memory SyncService for unit tests and Simulator when CloudKit is unavailable.
actor InMemorySyncService: SyncService {
    private var store: [UUID: SyncRecord] = [:]
    private(set) var syncCallCount = 0

    func sync() async throws {
        syncCallCount += 1
    }

    func upload(localChanges: [SyncRecord]) async throws {
        for record in localChanges {
            if let existing = store[record.id],
               !SyncMergePolicy.shouldApplyRemote(
                localUpdatedAt: existing.updatedAt,
                remoteUpdatedAt: record.updatedAt
               ) {
                continue
            }
            store[record.id] = record
        }
    }

    func fetchRemoteChanges(since token: String?) async throws -> SyncBatch {
        _ = token
        return SyncBatch(records: Array(store.values), serverChangeToken: "mem-\(store.count)")
    }

    func seed(_ records: [SyncRecord]) {
        for record in records {
            store[record.id] = record
        }
    }

    func storedRecords() -> [SyncRecord] {
        Array(store.values)
    }
}
