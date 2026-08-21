import Foundation

/// Soft calorie-target nudge from weight trend vs stated goal (V1.2 adaptive goals).
struct AdaptiveGoalSuggestion: Equatable, Sendable {
    var currentCalories: Int
    var suggestedCalories: Int
    var proteinGrams: Int
    var carbGrams: Int
    var fatGrams: Int
    var title: String
    var detail: String
    var observedKgPerWeek: Double
    var expectedKgPerWeek: Double

    var calorieDelta: Int { suggestedCalories - currentCalories }
}

enum AdaptiveGoalPreference {
    static let enabledKey = "plate.adaptiveGoals.enabled"
    static let dismissedUntilKey = "plate.adaptiveGoals.dismissedUntil"

    /// Default on — soft suggestion only; never auto-applies.
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }

    static func isDismissed(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard let until = defaults.object(forKey: dismissedUntilKey) as? Date else { return false }
        return now < until
    }

    static func dismiss(forDays days: Int = 14, now: Date = .now, defaults: UserDefaults = .standard) {
        let until = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now.addingTimeInterval(Double(days) * 86_400)
        defaults.set(until, forKey: dismissedUntilKey)
    }

    static func clearDismissal(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: dismissedUntilKey)
    }
}

/// Deterministic adaptive-target math — no network, supportive copy only.
enum AdaptiveGoalEngine {
    /// Rough energy density used only for nudge sizing (not medical advice).
    static let kcalPerKg: Double = 7_700

    static func expectedKgPerWeek(goalType: GoalType, pace: PacePreference = .moderate) -> Double {
        switch goalType {
        case .trackOnly:
            return 0
        case .maintainWeight:
            return 0
        case .loseWeight:
            switch pace {
            case .slow: return -0.25
            case .moderate: return -0.45
            case .faster: return -0.70
            }
        case .gainWeight:
            switch pace {
            case .slow: return 0.15
            case .moderate: return 0.25
            case .faster: return 0.40
            }
        }
    }

    /// Linear kg/week from earliest to latest weigh-in. Needs ≥14 days span and 2+ entries.
    static func observedKgPerWeek(entries: [WeightEntry], minimumSpanDays: Double = 14) -> Double? {
        let sorted = entries.sorted { $0.recordedAt < $1.recordedAt }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else { return nil }
        let days = last.recordedAt.timeIntervalSince(first.recordedAt) / 86_400
        guard days >= minimumSpanDays else { return nil }
        let weeks = days / 7.0
        guard weeks > 0 else { return nil }
        return (last.kilograms - first.kilograms) / weeks
    }

    static func suggestion(
        goalType: GoalType,
        macroPreference: MacroPreference,
        currentTarget: NutritionTargetSnapshot,
        weightEntries: [WeightEntry],
        daysLoggedRecently: Int,
        pace: PacePreference = .moderate
    ) -> AdaptiveGoalSuggestion? {
        guard goalType != .trackOnly else { return nil }
        guard daysLoggedRecently >= 5 else { return nil }
        guard let observed = observedKgPerWeek(entries: weightEntries) else { return nil }

        let expected = expectedKgPerWeek(goalType: goalType, pace: pace)
        let drift = observed - expected
        // Ignore noise under ~0.2 kg/week.
        guard abs(drift) >= 0.20 else { return nil }

        // Positive drift vs expected ⇒ weight higher than hoped ⇒ lower calories for lose/maintain;
        // for gain, positive drift means faster than planned ⇒ slightly lower surplus.
        let dailyError = drift * kcalPerKg / 7.0
        var adjustment = -dailyError
        // Clamp to gentle nudges.
        adjustment = min(200, max(-200, adjustment))
        let rounded = TargetCalculator.roundCalories(Double(currentTarget.calories) + adjustment)
        let suggested = max(1_200, rounded)
        guard abs(suggested - currentTarget.calories) >= 50 else { return nil }

        let macros = TargetCalculator.macroGrams(calories: suggested, preference: macroPreference)
        let (title, detail) = copy(
            goalType: goalType,
            observed: observed,
            expected: expected,
            current: currentTarget.calories,
            suggested: suggested
        )

        return AdaptiveGoalSuggestion(
            currentCalories: currentTarget.calories,
            suggestedCalories: suggested,
            proteinGrams: macros.protein,
            carbGrams: macros.carbs,
            fatGrams: macros.fat,
            title: title,
            detail: detail,
            observedKgPerWeek: observed,
            expectedKgPerWeek: expected
        )
    }

    static func makeTarget(from suggestion: AdaptiveGoalSuggestion, effectiveDate: Date = .now) -> NutritionTargetSnapshot {
        NutritionTargetSnapshot(
            effectiveDate: effectiveDate,
            calories: suggestion.suggestedCalories,
            proteinGrams: suggestion.proteinGrams,
            carbGrams: suggestion.carbGrams,
            fatGrams: suggestion.fatGrams,
            source: .adaptiveSuggestion
        )
    }

    private static func copy(
        goalType: GoalType,
        observed: Double,
        expected: Double,
        current: Int,
        suggested: Int
    ) -> (String, String) {
        let observedText = String(format: "%+.2f kg/week", observed)
        let direction = suggested < current ? "a slightly lower" : "a slightly higher"
        switch goalType {
        case .loseWeight:
            if observed > expected {
                return (
                    "Gentle target tweak",
                    "Weight has been moving about \(observedText). If it feels right, try \(direction) calorie target (\(suggested) vs \(current)) — always optional."
                )
            }
            return (
                "Ease up a little",
                "You’ve been losing a bit faster than the gentle pace (\(observedText)). A slightly higher target (\(suggested)) can keep things sustainable."
            )
        case .gainWeight:
            if observed < expected {
                return (
                    "Gentle target tweak",
                    "Weight trend is about \(observedText). A slightly higher target (\(suggested)) may help if building is still the goal."
                )
            }
            return (
                "Steady is fine",
                "You’re gaining a bit quicker than planned (\(observedText)). \(suggested) cal is a softer suggestion — only if you want it."
            )
        case .maintainWeight:
            return (
                "Maintenance check-in",
                "Weight has drifted about \(observedText). \(suggested) cal is a small optional adjustment toward steadier maintenance."
            )
        case .trackOnly:
            return ("", "")
        }
    }
}
