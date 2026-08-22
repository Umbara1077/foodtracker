import Combine
import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case goal
    case units
    case age
    case height
    case weight
    case targetWeight
    case formula
    case activity
    case pace
    case macros
    case result

    var id: Int { rawValue }

    var progress: Double {
        Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
    }

    var showsProgressBar: Bool {
        self != .welcome && self != .result
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    private let profileRepository: any ProfileRepository
    private let targetRepository: any TargetRepository
    private let analytics: any AnalyticsClient
    private let onFinished: () -> Void

    @Published var step: OnboardingStep = .welcome
    @Published var draft = UserProfile.blank
    @Published var pace: PacePreference = .moderate
    @Published var activity: ActivityLevel = .lightlyActive
    @Published var heightFeet: Int = 5
    @Published var heightInches: Double = 8
    @Published var heightCmText: String = "170"
    @Published var weightText: String = "70"
    @Published var targetWeightText: String = ""
    @Published var ageText: String = "30"
    @Published var manualCaloriesText: String = "2000"
    @Published var editedCaloriesText: String = ""
    @Published var calculated: TargetCalculator.Output?
    @Published var errorMessage: String?

    init(
        profileRepository: any ProfileRepository,
        targetRepository: any TargetRepository,
        analytics: any AnalyticsClient,
        onFinished: @escaping () -> Void
    ) {
        self.profileRepository = profileRepository
        self.targetRepository = targetRepository
        self.analytics = analytics
        self.onFinished = onFinished
        analytics.track(.onboardingStarted)
    }

    var isUnder18: Bool {
        (Int(ageText) ?? 18) < 18
    }

    var needsPace: Bool {
        draft.goalType == .loseWeight || draft.goalType == .gainWeight
    }

    var needsBodyMetrics: Bool {
        draft.goalType != .trackOnly
    }

    func goBack() {
        errorMessage = nil
        guard let idx = OnboardingStep.allCases.firstIndex(of: step), idx > 0 else { return }
        step = OnboardingStep.allCases[idx - 1]
    }

    func continueFromWelcome(knowsTargets: Bool) {
        if knowsTargets {
            draft.goalType = .trackOnly
            draft.formulaSex = .skipManual
            step = .units
        } else {
            step = .goal
        }
    }

    func advance() {
        errorMessage = nil
        switch step {
        case .welcome:
            step = .goal
        case .goal:
            step = .units
        case .units:
            step = .age
        case .age:
            guard applyAge() else { return }
            if isUnder18 {
                draft.goalType = .trackOnly
                draft.formulaSex = .skipManual
            }
            step = needsBodyMetrics && !isUnder18 ? .height : .macros
        case .height:
            guard applyHeight() else { return }
            step = .weight
        case .weight:
            guard applyWeight() else { return }
            step = (draft.goalType == .loseWeight || draft.goalType == .gainWeight) ? .targetWeight : .formula
        case .targetWeight:
            applyTargetWeight()
            step = .formula
        case .formula:
            if draft.formulaSex == nil { draft.formulaSex = .maleEquation }
            if draft.formulaSex == .skipManual {
                step = .macros
            } else {
                step = .activity
            }
        case .activity:
            draft.activityMultiplier = activity.multiplier
            step = needsPace ? .pace : .macros
        case .pace:
            step = .macros
        case .macros:
            recalculate()
            step = .result
        case .result:
            Task { await finish() }
        }
    }

    func recalculate() {
        let weight = draft.currentWeightKg ?? 70
        let height = draft.heightCm ?? 170
        let age = draft.age ?? 30
        let sex = draft.formulaSex ?? .skipManual

        @Published var manual: Int?
        if draft.goalType == .trackOnly || sex == .skipManual {
            manual = Int(manualCaloriesText) ?? 2000
        }

        let output = TargetCalculator.calculate(
            .init(
                weightKg: weight,
                heightCm: height,
                age: age,
                formulaSex: sex,
                activityMultiplier: draft.activityMultiplier,
                goalType: draft.goalType,
                pace: pace,
                macroPreference: draft.macroPreference,
                manualCalories: manual
            )
        )
        calculated = output
        if editedCaloriesText.isEmpty {
            editedCaloriesText = "\(output.calories)"
        }
    }

    /// Macros for the calories currently shown on the result screen.
    var displayedMacros: (protein: Int, carbs: Int, fat: Int) {
        let calories = Int(editedCaloriesText) ?? calculated?.calories ?? 0
        return TargetCalculator.macroGrams(calories: calories, preference: draft.macroPreference)
    }

    func finish() async {
        errorMessage = nil
        recalculate()
        guard let calculated else {
            errorMessage = "Could not calculate a target."
            return
        }

        // Apply edited calories if user changed the result.
        let finalCalories = Int(editedCaloriesText) ?? calculated.calories
        let macros = TargetCalculator.macroGrams(
            calories: finalCalories,
            preference: draft.macroPreference
        )
        let source: TargetSource = (finalCalories == calculated.calories && calculated.source == .onboardingEstimate)
            ? .onboardingEstimate
            : .manual

        draft.activityMultiplier = activity.multiplier
        draft.onboardingComplete = true

        let snapshot = NutritionTargetSnapshot(
            calories: finalCalories,
            proteinGrams: macros.protein,
            carbGrams: macros.carbs,
            fatGrams: macros.fat,
            source: source
        )

        do {
            try await profileRepository.saveProfile(draft)
            try await targetRepository.saveTarget(snapshot)
            analytics.track(.onboardingCompleted)
            onFinished()
        } catch {
            errorMessage = "Could not save your targets. Try again."
        }
    }

    private func applyAge() -> Bool {
        guard let age = Int(ageText), (13...100).contains(age) else {
            errorMessage = "Enter an age between 13 and 100."
            return false
        }
        draft.age = age
        return true
    }

    private func applyHeight() -> Bool {
        if draft.unitSystem == .metric {
            guard let cm = Double(heightCmText), (100...250).contains(cm) else {
                errorMessage = "Enter height in centimeters."
                return false
            }
            draft.heightCm = cm
        } else {
            let cm = UnitConversion.centimeters(feet: heightFeet, inches: heightInches)
            guard (100...250).contains(cm) else {
                errorMessage = "Enter a valid height."
                return false
            }
            draft.heightCm = cm
        }
        return true
    }

    private func applyWeight() -> Bool {
        guard let value = Double(weightText), value > 0 else {
            errorMessage = "Enter your current weight."
            return false
        }
        draft.currentWeightKg = draft.unitSystem == .metric
            ? value
            : UnitConversion.kilograms(fromPounds: value)
        return true
    }

    private func applyTargetWeight() {
        guard let value = Double(targetWeightText), value > 0 else {
            draft.targetWeightKg = nil
            return
        }
        draft.targetWeightKg = draft.unitSystem == .metric
            ? value
            : UnitConversion.kilograms(fromPounds: value)
    }
}
