import Foundation
import SwiftData

@Model
final class UserProfileEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var onboardingComplete: Bool
    var unitSystemRaw: String
    var age: Int?
    var heightCm: Double?
    var currentWeightKg: Double?
    var targetWeightKg: Double?
    var goalTypeRaw: String
    var activityMultiplier: Double
    var formulaSexRaw: String?
    var macroPreferenceRaw: String
    var cloudAIConsentVersion: String?
    var healthKitEnabled: Bool

    init(from profile: UserProfile) {
        self.id = profile.id
        self.createdAt = profile.createdAt
        self.onboardingComplete = profile.onboardingComplete
        self.unitSystemRaw = profile.unitSystem.rawValue
        self.age = profile.age
        self.heightCm = profile.heightCm
        self.currentWeightKg = profile.currentWeightKg
        self.targetWeightKg = profile.targetWeightKg
        self.goalTypeRaw = profile.goalType.rawValue
        self.activityMultiplier = profile.activityMultiplier
        self.formulaSexRaw = profile.formulaSex?.rawValue
        self.macroPreferenceRaw = profile.macroPreference.rawValue
        self.cloudAIConsentVersion = profile.cloudAIConsentVersion
        self.healthKitEnabled = profile.healthKitEnabled
    }

    func apply(_ profile: UserProfile) {
        id = profile.id
        createdAt = profile.createdAt
        onboardingComplete = profile.onboardingComplete
        unitSystemRaw = profile.unitSystem.rawValue
        age = profile.age
        heightCm = profile.heightCm
        currentWeightKg = profile.currentWeightKg
        targetWeightKg = profile.targetWeightKg
        goalTypeRaw = profile.goalType.rawValue
        activityMultiplier = profile.activityMultiplier
        formulaSexRaw = profile.formulaSex?.rawValue
        macroPreferenceRaw = profile.macroPreference.rawValue
        cloudAIConsentVersion = profile.cloudAIConsentVersion
        healthKitEnabled = profile.healthKitEnabled
    }

    func asDomain() -> UserProfile {
        UserProfile(
            id: id,
            createdAt: createdAt,
            unitSystem: UnitSystem(rawValue: unitSystemRaw) ?? .metric,
            age: age,
            heightCm: heightCm,
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg,
            goalType: GoalType(rawValue: goalTypeRaw) ?? .maintainWeight,
            activityMultiplier: activityMultiplier,
            formulaSex: formulaSexRaw.flatMap(FormulaSex.init(rawValue:)),
            macroPreference: MacroPreference(rawValue: macroPreferenceRaw) ?? .balanced,
            onboardingComplete: onboardingComplete,
            cloudAIConsentVersion: cloudAIConsentVersion,
            healthKitEnabled: healthKitEnabled
        )
    }
}

@Model
final class NutritionTargetEntity {
    @Attribute(.unique) var id: UUID
    var effectiveFrom: Date
    var calories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var sourceRaw: String
    var createdAt: Date

    init(from snapshot: NutritionTargetSnapshot) {
        self.id = snapshot.id
        self.effectiveFrom = snapshot.effectiveDate
        self.calories = snapshot.calories
        self.proteinGrams = snapshot.proteinGrams
        self.carbsGrams = snapshot.carbGrams
        self.fatGrams = snapshot.fatGrams
        self.sourceRaw = snapshot.source.rawValue
        self.createdAt = .now
    }

    func asDomain() -> NutritionTargetSnapshot {
        NutritionTargetSnapshot(
            id: id,
            effectiveDate: effectiveFrom,
            calories: calories,
            proteinGrams: proteinGrams,
            carbGrams: carbsGrams,
            fatGrams: fatGrams,
            source: TargetSource(rawValue: sourceRaw) ?? .manual
        )
    }
}
