import Foundation

/// Soft daily micronutrient targets for display (PRODUCT_SPEC §6.3 advanced micronutrients).
/// Not medical advice — defaults follow common public guidelines; users can hide the section.
struct MicronutrientGoals: Sendable, Equatable {
    var fiberGrams: Double
    /// Soft upper awareness target for total sugars (g).
    var sugarGrams: Double
    /// Soft upper awareness target for sodium (mg).
    var sodiumMg: Double

    static let `default` = MicronutrientGoals(
        fiberGrams: 28,
        sugarGrams: 50,
        sodiumMg: 2_300
    )
}

enum MicronutrientPreference {
    static let enabledKey = "plate.micronutrients.enabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}

enum MicronutrientMath {
    /// Average of present optional values across logged days (nil days omitted).
    static func averagePresent(_ values: [Double?]) -> Double? {
        let present = values.compactMap { $0 }
        guard !present.isEmpty else { return nil }
        return present.reduce(0, +) / Double(present.count)
    }

    static func hasAnyMicro(_ nutrients: NutrientSet) -> Bool {
        nutrients.fiber != nil || nutrients.sugar != nil || nutrients.sodiumMg != nil
    }
}
