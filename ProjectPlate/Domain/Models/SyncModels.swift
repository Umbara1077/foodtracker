import Foundation

// MARK: - Sync DTOs (CloudKit-agnostic — PRODUCT_SPEC §7.4)

enum SyncRecordKind: String, Codable, Sendable, CaseIterable {
    case meal
    case weight
    case profile
    case target
    case savedMeal
}

struct SyncRecord: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var kind: SyncRecordKind
    var updatedAt: Date
    var deleted: Bool
    /// JSON-encoded domain payload for the kind (empty when deleted).
    var payloadJSON: Data

    init(
        id: UUID,
        kind: SyncRecordKind,
        updatedAt: Date,
        deleted: Bool = false,
        payloadJSON: Data = Data()
    ) {
        self.id = id
        self.kind = kind
        self.updatedAt = updatedAt
        self.deleted = deleted
        self.payloadJSON = payloadJSON
    }
}

struct SyncBatch: Codable, Sendable, Equatable {
    var records: [SyncRecord]
    var serverChangeToken: String?

    static let empty = SyncBatch(records: [], serverChangeToken: nil)
}

protocol SyncService: Sendable {
    func sync() async throws
    func upload(localChanges: [SyncRecord]) async throws
    func fetchRemoteChanges(since token: String?) async throws -> SyncBatch
}

enum SyncServiceError: Error, LocalizedError, Sendable {
    case disabled
    case accountUnavailable
    case encodingFailed
    case decodingFailed
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "iCloud sync is turned off."
        case .accountUnavailable:
            "Sign in to iCloud in Settings to sync Project Plate."
        case .encodingFailed:
            "Could not prepare diary data for sync."
        case .decodingFailed:
            "Could not read a synced diary record."
        case .transport(let message):
            message
        }
    }
}

enum SyncMergePolicy {
    /// Last-write-wins by `updatedAt`. Equal timestamps prefer remote (idempotent).
    static func shouldApplyRemote(localUpdatedAt: Date?, remoteUpdatedAt: Date) -> Bool {
        guard let localUpdatedAt else { return true }
        return remoteUpdatedAt >= localUpdatedAt
    }
}

enum SyncRecordCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encodePayload<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw SyncServiceError.encodingFailed
        }
    }

    static func decodePayload<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SyncServiceError.decodingFailed
        }
    }

    static func makeMeal(_ meal: MealRecord) throws -> SyncRecord {
        SyncRecord(
            id: meal.id,
            kind: .meal,
            updatedAt: meal.updatedAt,
            payloadJSON: try encodePayload(meal)
        )
    }

    static func makeWeight(_ entry: WeightEntry) throws -> SyncRecord {
        SyncRecord(
            id: entry.id,
            kind: .weight,
            updatedAt: entry.recordedAt,
            payloadJSON: try encodePayload(entry)
        )
    }

    static func makeProfile(_ profile: UserProfile) throws -> SyncRecord {
        SyncRecord(
            id: profile.id,
            kind: .profile,
            updatedAt: profile.createdAt,
            payloadJSON: try encodePayload(profile)
        )
    }

    static func makeTarget(_ target: NutritionTargetSnapshot) throws -> SyncRecord {
        SyncRecord(
            id: target.id,
            kind: .target,
            updatedAt: target.effectiveDate,
            payloadJSON: try encodePayload(target)
        )
    }

    static func makeSavedMeal(_ template: SavedMealTemplate) throws -> SyncRecord {
        SyncRecord(
            id: template.id,
            kind: .savedMeal,
            updatedAt: template.lastUsedAt,
            payloadJSON: try encodePayload(template)
        )
    }
}

enum CloudSyncPreference {
    static let enabledKey = "plate.icloudSync.enabled"
    static let lastSyncKey = "plate.icloudSync.lastSuccess"
    static let changeTokenKey = "plate.icloudSync.changeToken"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }

    static func lastSyncDate(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: lastSyncKey) as? Date
    }

    static func setLastSyncDate(_ date: Date?, defaults: UserDefaults = .standard) {
        defaults.set(date, forKey: lastSyncKey)
    }

    static func changeToken(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: changeTokenKey)
    }

    static func setChangeToken(_ token: String?, defaults: UserDefaults = .standard) {
        defaults.set(token, forKey: changeTokenKey)
    }
}
