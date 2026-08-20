import Foundation

/// Collects local diary state, merges remote SyncRecords, and drives a SyncService.
actor DiarySyncCoordinator {
    private let mealRepository: any MealRepository
    private let weightRepository: any WeightRepository
    private let profileRepository: any ProfileRepository
    private let targetRepository: any TargetRepository
    private let savedMealRepository: any SavedMealRepository
    private let syncService: any SyncService
    private let defaults: UserDefaults
    private var isSyncing = false

    init(
        mealRepository: any MealRepository,
        weightRepository: any WeightRepository,
        profileRepository: any ProfileRepository,
        targetRepository: any TargetRepository,
        savedMealRepository: any SavedMealRepository,
        syncService: any SyncService,
        defaults: UserDefaults = .standard
    ) {
        self.mealRepository = mealRepository
        self.weightRepository = weightRepository
        self.profileRepository = profileRepository
        self.targetRepository = targetRepository
        self.savedMealRepository = savedMealRepository
        self.syncService = syncService
        self.defaults = defaults
    }

    func syncIfEnabled(calendar: Calendar = .current) async throws {
        guard CloudSyncPreference.isEnabled(defaults: defaults) else {
            throw SyncServiceError.disabled
        }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let local = try await collectLocalRecords(calendar: calendar)
        let token = CloudSyncPreference.changeToken(defaults: defaults)
        let remote = try await syncService.fetchRemoteChanges(since: token)
        try await applyRemote(remote.records, local: local)
        let refreshed = try await collectLocalRecords(calendar: calendar)
        try await syncService.upload(localChanges: refreshed)
        if let newToken = remote.serverChangeToken {
            CloudSyncPreference.setChangeToken(newToken, defaults: defaults)
        }
        CloudSyncPreference.setLastSyncDate(.now, defaults: defaults)
        try await syncService.sync()
    }

    func collectLocalRecords(calendar: Calendar = .current) async throws -> [SyncRecord] {
        var records: [SyncRecord] = []

        if let profile = try await profileRepository.loadProfile() {
            records.append(try SyncRecordCodec.makeProfile(profile))
        }
        for target in try await targetRepository.allTargets() {
            records.append(try SyncRecordCodec.makeTarget(target))
        }
        for template in try await savedMealRepository.all() {
            records.append(try SyncRecordCodec.makeSavedMeal(template))
        }

        let end = Date()
        let start = calendar.date(byAdding: .year, value: -5, to: end) ?? end
        let weights = try await weightRepository.entries(from: start, to: end)
        for weight in weights {
            records.append(try SyncRecordCodec.makeWeight(weight))
        }

        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            for meal in try await mealRepository.meals(on: cursor, calendar: calendar) {
                records.append(try SyncRecordCodec.makeMeal(meal))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return records
    }

    func applyRemote(_ remoteRecords: [SyncRecord], local: [SyncRecord]) async throws {
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for remote in remoteRecords {
            let localRecord = localByID[remote.id]
            guard SyncMergePolicy.shouldApplyRemote(
                localUpdatedAt: localRecord?.updatedAt,
                remoteUpdatedAt: remote.updatedAt
            ) else { continue }

            if remote.deleted {
                try await deleteLocal(remote)
                continue
            }
            try await upsertLocal(remote)
        }
    }

    private func deleteLocal(_ remote: SyncRecord) async throws {
        switch remote.kind {
        case .meal:
            try await mealRepository.delete(id: remote.id)
        case .weight:
            try await weightRepository.delete(id: remote.id)
        case .savedMeal:
            try await savedMealRepository.delete(id: remote.id)
        case .profile, .target:
            break
        }
    }

    private func upsertLocal(_ remote: SyncRecord) async throws {
        switch remote.kind {
        case .meal:
            let meal = try SyncRecordCodec.decodePayload(MealRecord.self, from: remote.payloadJSON)
            try await mealRepository.save(meal)
        case .weight:
            let weight = try SyncRecordCodec.decodePayload(WeightEntry.self, from: remote.payloadJSON)
            try await weightRepository.save(weight)
        case .profile:
            let profile = try SyncRecordCodec.decodePayload(UserProfile.self, from: remote.payloadJSON)
            try await profileRepository.saveProfile(profile)
        case .target:
            let target = try SyncRecordCodec.decodePayload(NutritionTargetSnapshot.self, from: remote.payloadJSON)
            try await targetRepository.saveTarget(target)
        case .savedMeal:
            let template = try SyncRecordCodec.decodePayload(SavedMealTemplate.self, from: remote.payloadJSON)
            try await savedMealRepository.upsert(template)
        }
    }
}
