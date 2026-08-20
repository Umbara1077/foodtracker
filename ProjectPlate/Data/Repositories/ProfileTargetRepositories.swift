import Foundation
import SwiftData

protocol ProfileRepository: Sendable {
    func loadProfile() async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
}

protocol TargetRepository: Sendable {
    func currentTarget(on date: Date) async throws -> NutritionTargetSnapshot?
    func saveTarget(_ snapshot: NutritionTargetSnapshot) async throws
    func allTargets() async throws -> [NutritionTargetSnapshot]
}

@ModelActor
actor SwiftDataProfileRepository: ProfileRepository {
    func loadProfile() async throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfileEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).first?.asDomain()
    }

    func saveProfile(_ profile: UserProfile) async throws {
        let profileID = profile.id
        let descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { $0.id == profileID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(profile)
        } else {
            // Replace any prior single-profile row for Phase 1 simplicity.
            let all = try modelContext.fetch(FetchDescriptor<UserProfileEntity>())
            all.forEach { modelContext.delete($0) }
            modelContext.insert(UserProfileEntity(from: profile))
        }
        try modelContext.save()
    }
}

@ModelActor
actor SwiftDataTargetRepository: TargetRepository {
    func currentTarget(on date: Date) async throws -> NutritionTargetSnapshot? {
        let descriptor = FetchDescriptor<NutritionTargetEntity>(
            sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]
        )
        let rows = try modelContext.fetch(descriptor)
        return rows.first(where: { $0.effectiveFrom <= date })?.asDomain() ?? rows.first?.asDomain()
    }

    func saveTarget(_ snapshot: NutritionTargetSnapshot) async throws {
        let snapshotID = snapshot.id
        let descriptor = FetchDescriptor<NutritionTargetEntity>(
            predicate: #Predicate { $0.id == snapshotID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(snapshot)
        } else {
            modelContext.insert(NutritionTargetEntity(from: snapshot))
        }
        try modelContext.save()
    }

    func allTargets() async throws -> [NutritionTargetSnapshot] {
        let descriptor = FetchDescriptor<NutritionTargetEntity>(
            sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.asDomain() }
    }
}

/// In-memory fakes for previews and unit tests that avoid SwiftData.
actor InMemoryProfileRepository: ProfileRepository {
    private var profile: UserProfile?

    init(profile: UserProfile? = nil) {
        self.profile = profile
    }

    func loadProfile() async throws -> UserProfile? { profile }

    func saveProfile(_ profile: UserProfile) async throws {
        self.profile = profile
    }
}

actor InMemoryTargetRepository: TargetRepository {
    private var targets: [NutritionTargetSnapshot] = []

    init(targets: [NutritionTargetSnapshot] = []) {
        self.targets = targets
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
    }

    func allTargets() async throws -> [NutritionTargetSnapshot] {
        targets.sorted { $0.effectiveDate > $1.effectiveDate }
    }
}
