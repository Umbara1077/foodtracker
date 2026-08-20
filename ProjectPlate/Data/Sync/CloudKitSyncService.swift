import CloudKit
import Foundation

/// Private-database CloudKit adapter. Domain types stay in SyncRecord payloads.
actor CloudKitSyncService: SyncService {
    static let recordType = "PlateSyncRecord"
    static let containerIdentifier = "iCloud.com.projectplate.app"

    private let container: CKContainer
    private let database: CKDatabase

    init(container: CKContainer = CKContainer(identifier: CloudKitSyncService.containerIdentifier)) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    func sync() async throws {
        // Fetch + upload are explicit; sync() is a no-op hook for future push metadata.
    }

    func upload(localChanges: [SyncRecord]) async throws {
        try await ensureAccount()
        guard !localChanges.isEmpty else { return }

        let records = localChanges.map(Self.makeCKRecord)
        let chunkSize = 100
        var index = 0
        while index < records.count {
            let end = min(index + chunkSize, records.count)
            let slice = Array(records[index..<end])
            let op = CKModifyRecordsOperation(recordsToSave: slice, recordIDsToDelete: nil)
            op.savePolicy = .changedKeys
            op.isAtomic = false
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: SyncServiceError.transport(error.localizedDescription))
                    }
                }
                database.add(op)
            }
            index = end
        }
    }

    func fetchRemoteChanges(since token: String?) async throws -> SyncBatch {
        try await ensureAccount()
        _ = token
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: true)]

        var collected: [SyncRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let (records, next): ([CKRecord], CKQueryOperation.Cursor?) = try await withCheckedThrowingContinuation { continuation in
                let operation: CKQueryOperation
                if let cursor {
                    operation = CKQueryOperation(cursor: cursor)
                } else {
                    operation = CKQueryOperation(query: query)
                }
                operation.resultsLimit = 100
                var page: [CKRecord] = []
                operation.recordMatchedBlock = { _, result in
                    if case .success(let record) = result {
                        page.append(record)
                    }
                }
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let nextCursor):
                        continuation.resume(returning: (page, nextCursor))
                    case .failure(let error):
                        continuation.resume(throwing: SyncServiceError.transport(error.localizedDescription))
                    }
                }
                database.add(operation)
            }
            collected.append(contentsOf: records.compactMap(Self.makeSyncRecord))
            cursor = next
        } while cursor != nil

        return SyncBatch(records: collected, serverChangeToken: ISO8601DateFormatter().string(from: Date()))
    }

    private func ensureAccount() async throws {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw SyncServiceError.accountUnavailable
        }
    }

    static func makeCKRecord(from syncRecord: SyncRecord) -> CKRecord {
        let recordID = CKRecord.ID(recordName: syncRecord.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["kind"] = syncRecord.kind.rawValue
        record["updatedAt"] = syncRecord.updatedAt
        record["deleted"] = syncRecord.deleted ? 1 : 0
        record["payload"] = syncRecord.payloadJSON
        return record
    }

    static func makeSyncRecord(from record: CKRecord) -> SyncRecord? {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let kindRaw = record["kind"] as? String,
            let kind = SyncRecordKind(rawValue: kindRaw),
            let updatedAt = record["updatedAt"] as? Date
        else { return nil }
        let deletedNumber = record["deleted"] as? Int ?? (record["deleted"] as? Int64).map(Int.init) ?? 0
        let payload = (record["payload"] as? Data) ?? Data()
        return SyncRecord(
            id: id,
            kind: kind,
            updatedAt: updatedAt,
            deleted: deletedNumber != 0,
            payloadJSON: payload
        )
    }
}
