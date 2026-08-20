import Foundation
import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            UserProfileEntity.self,
            NutritionTargetEntity.self,
        ])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

@Model
final class UserProfileEntity {
    var id: UUID
    var createdAt: Date
    var onboardingComplete: Bool
    var unitSystemRaw: String
    var cloudAIConsentVersion: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        onboardingComplete: Bool = false,
        unitSystemRaw: String = "metric",
        cloudAIConsentVersion: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.onboardingComplete = onboardingComplete
        self.unitSystemRaw = unitSystemRaw
        self.cloudAIConsentVersion = cloudAIConsentVersion
    }
}

@Model
final class NutritionTargetEntity {
    var id: UUID
    var effectiveFrom: Date
    var calories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var sourceRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        effectiveFrom: Date = .now,
        calories: Int = 2000,
        proteinGrams: Int = 150,
        carbsGrams: Int = 200,
        fatGrams: Int = 65,
        sourceRaw: String = "default",
        createdAt: Date = .now
    ) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.sourceRaw = sourceRaw
        self.createdAt = createdAt
    }
}
