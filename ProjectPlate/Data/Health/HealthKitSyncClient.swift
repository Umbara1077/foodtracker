import Foundation
import HealthKit

/// Live HealthKit adapter. Never crashes when Health data is unavailable or denied.
final class HealthKitSyncClient: HealthSyncClient, @unchecked Sendable {
    private let store: HKHealthStore?

    init(store: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil) {
        self.store = store
    }

    var isDataAvailable: Bool { store != nil }

    private var shareTypes: Set<HKSampleType> {
        Set([
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.bodyMass),
        ].compactMap { $0 })
    }

    private var readTypes: Set<HKObjectType> {
        Set([HKQuantityType(.bodyMass)].compactMap { $0 as HKObjectType })
    }

    func authorizationStatus() -> HealthAuthStatus {
        guard let store, let energy = HKQuantityType(.dietaryEnergyConsumed) else {
            return .unavailable
        }
        switch store.authorizationStatus(for: energy) {
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .sharingDenied
        case .sharingAuthorized: return .sharingAuthorized
        @unknown default: return .sharingDenied
        }
    }

    func requestAuthorization() async throws -> Bool {
        guard let store else { return false }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        return authorizationStatus() == .sharingAuthorized || authorizationStatus() == .sharingDenied
        // Denied still "completed" the prompt; app continues offline.
    }

    func writeMealNutrition(_ meal: MealRecord) async throws -> MealHealthKitAnchors {
        guard let store else { return MealHealthKitAnchors() }
        let date = meal.eatenAt
        var anchors = MealHealthKitAnchors()

        if let type = HKQuantityType(.dietaryEnergyConsumed) {
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: meal.nutrients.calories),
                start: date,
                end: date,
                metadata: metadata(for: meal)
            )
            try await store.save(sample)
            anchors.energyUUID = sample.uuid.uuidString
        }
        if let type = HKQuantityType(.dietaryProtein) {
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: .gram(), doubleValue: meal.nutrients.protein),
                start: date,
                end: date,
                metadata: metadata(for: meal)
            )
            try await store.save(sample)
            anchors.proteinUUID = sample.uuid.uuidString
        }
        if let type = HKQuantityType(.dietaryCarbohydrates) {
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: .gram(), doubleValue: meal.nutrients.carbs),
                start: date,
                end: date,
                metadata: metadata(for: meal)
            )
            try await store.save(sample)
            anchors.carbsUUID = sample.uuid.uuidString
        }
        if let type = HKQuantityType(.dietaryFatTotal) {
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: .gram(), doubleValue: meal.nutrients.fat),
                start: date,
                end: date,
                metadata: metadata(for: meal)
            )
            try await store.save(sample)
            anchors.fatUUID = sample.uuid.uuidString
        }
        return anchors
    }

    func deleteMealNutrition(_ anchors: MealHealthKitAnchors) async throws {
        guard let store else { return }
        let typeIDs: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
        ]
        for uuidString in anchors.allUUIDs {
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            let predicate = HKQuery.predicateForObject(with: uuid)
            for typeID in typeIDs {
                guard let type = HKQuantityType(typeID) else { continue }
                _ = try? await store.deleteObjects(of: type, predicate: predicate)
            }
        }
    }

    func writeBodyMass(_ entry: WeightEntry) async throws -> String? {
        guard let store, let type = HKQuantityType(.bodyMass) else { return nil }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: entry.kilograms),
            start: entry.recordedAt,
            end: entry.recordedAt,
            metadata: [
                HKMetadataKeyExternalUUID: entry.id.uuidString,
            ]
        )
        try await store.save(sample)
        return sample.uuid.uuidString
    }

    func readBodyMass(from start: Date, to end: Date) async throws -> [WeightEntry] {
        guard let store, let type = HKQuantityType(.bodyMass) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let mapped: [WeightEntry] = (samples as? [HKQuantitySample] ?? []).map { sample in
                    WeightEntry(
                        recordedAt: sample.startDate,
                        kilograms: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                        note: nil,
                        source: .healthKit,
                        healthKitUUID: sample.uuid.uuidString
                    )
                }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    private func metadata(for meal: MealRecord) -> [String: Any] {
        [
            HKMetadataKeyExternalUUID: meal.id.uuidString,
            "ProjectPlateMealTitle": meal.title,
        ]
    }
}
