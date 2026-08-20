import Foundation

struct MealHealthKitAnchors: Codable, Sendable, Equatable {
    var energyUUID: String?
    var proteinUUID: String?
    var carbsUUID: String?
    var fatUUID: String?

    var allUUIDs: [String] {
        [energyUUID, proteinUUID, carbsUUID, fatUUID].compactMap { $0 }
    }

    var isEmpty: Bool { allUUIDs.isEmpty }
}

enum HealthAuthStatus: Sendable, Equatable {
    case notDetermined
    case sharingDenied
    case sharingAuthorized
    case unavailable
}

protocol HealthSyncClient: Sendable {
    var isDataAvailable: Bool { get }
    func authorizationStatus() -> HealthAuthStatus
    func requestAuthorization() async throws -> Bool
    /// Writes dietary samples. Returns anchors for dedupe/delete. No-op when unauthorized.
    func writeMealNutrition(_ meal: MealRecord) async throws -> MealHealthKitAnchors
    func deleteMealNutrition(_ anchors: MealHealthKitAnchors) async throws
    func writeBodyMass(_ entry: WeightEntry) async throws -> String?
    /// Imports body-mass samples; caller dedupes via `healthKitUUID`.
    func readBodyMass(from start: Date, to end: Date) async throws -> [WeightEntry]
}

struct NoOpHealthSyncClient: HealthSyncClient {
    var isDataAvailable: Bool { false }

    func authorizationStatus() -> HealthAuthStatus { .unavailable }

    func requestAuthorization() async throws -> Bool { false }

    func writeMealNutrition(_ meal: MealRecord) async throws -> MealHealthKitAnchors {
        MealHealthKitAnchors()
    }

    func deleteMealNutrition(_ anchors: MealHealthKitAnchors) async throws {}

    func writeBodyMass(_ entry: WeightEntry) async throws -> String? { nil }

    func readBodyMass(from start: Date, to end: Date) async throws -> [WeightEntry] { [] }
}

/// Coordinates diary persistence with optional HealthKit writes / deletes.
struct DiaryService: Sendable {
    var mealRepository: any MealRepository
    var weightRepository: any WeightRepository
    var profileRepository: any ProfileRepository
    var health: any HealthSyncClient
    var savedMeals: any SavedMealRepository

    func saveMeal(_ meal: MealRecord) async throws {
        var saved = meal
        if await isHealthEnabled() {
            // Replace prior samples if we already wrote this meal.
            if let prior = meal.healthKitAnchors, !prior.isEmpty {
                try? await health.deleteMealNutrition(prior)
            }
            if let anchors = try? await health.writeMealNutrition(meal), !anchors.isEmpty {
                saved.healthKitAnchors = anchors
            }
        }
        saved.updatedAt = .now
        try await mealRepository.save(saved)
        try? await savedMeals.recordUsage(of: saved)
    }

    func deleteMeal(_ meal: MealRecord) async throws {
        if await isHealthEnabled(), let anchors = meal.healthKitAnchors, !anchors.isEmpty {
            try? await health.deleteMealNutrition(anchors)
        }
        try await mealRepository.delete(id: meal.id)
    }

    func saveWeight(_ entry: WeightEntry) async throws {
        var saved = entry
        if await isHealthEnabled() {
            if let uuid = try? await health.writeBodyMass(entry) {
                saved.healthKitUUID = uuid
            }
        }
        try await weightRepository.save(saved)
        if var profile = try await profileRepository.loadProfile() {
            profile.currentWeightKg = saved.kilograms
            try await profileRepository.saveProfile(profile)
        }
    }

    /// Imports HealthKit body mass samples that are not already stored locally.
    func importWeightsFromHealth(from start: Date, to end: Date) async throws -> Int {
        guard await isHealthEnabled() else { return 0 }
        let remote = try await health.readBodyMass(from: start, to: end)
        let existing = try await weightRepository.entries(from: start, to: end)
        let known = Set(existing.compactMap(\.healthKitUUID))
        var imported = 0
        for sample in remote {
            guard let hk = sample.healthKitUUID, !known.contains(hk) else { continue }
            try await weightRepository.save(sample)
            imported += 1
        }
        return imported
    }

    private func isHealthEnabled() async -> Bool {
        guard health.isDataAvailable else { return false }
        guard let profile = try? await profileRepository.loadProfile() else { return false }
        return profile.healthKitEnabled
    }
}
