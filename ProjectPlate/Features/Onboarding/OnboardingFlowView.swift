import SwiftUI

struct OnboardingFlowView: View {
    @StateObject private var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.step.showsProgressBar {
                ProgressView(value: viewModel.step.progress)
                    .tint(Color.brandPrimary)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.space8)
            }

            Group {
                switch viewModel.step {
                case .welcome: welcome
                case .goal: goal
                case .units: units
                case .age: age
                case .height: height
                case .weight: weight
                case .targetWeight: targetWeight
                case .formula: formula
                case .activity: activity
                case .pace: pace
                case .macros: macros
                case .result: result
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(Color.statusError)
                    .padding(.horizontal, Spacing.screenHorizontal)
            }

            bottomBar
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.space12) {
            if viewModel.step != .welcome {
                HStack {
                    if viewModel.step != .result {
                        Button("Back", action: viewModel.goBack)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }
            }

            if viewModel.step == .welcome {
                PrimaryButton(title: "Continue") {
                    viewModel.continueFromWelcome(knowsTargets: false)
                }
                Button("I already know my targets") {
                    viewModel.continueFromWelcome(knowsTargets: true)
                }
                .font(Typography.supporting.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
            } else if viewModel.step == .result {
                PrimaryButton(title: "Use this target") {
                    Task { await viewModel.finish() }
                }
                Text("Adjust the calorie field above if you want a different starting number.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.step == .targetWeight {
                PrimaryButton(title: "Continue", action: viewModel.advance)
                Button("Skip") { viewModel.advance() }
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
            } else {
                PrimaryButton(title: "Continue", action: viewModel.advance)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.space16)
        .background(Color.backgroundPrimary)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Spacing.space16) {
            Text("Track food without the homework.")
                .font(Typography.largeTitle)
                .foregroundStyle(Color.textPrimary)
            Text("Snap a meal, review the estimate, and keep moving.")
                .font(Typography.body)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .padding(Spacing.screenHorizontal)
        .padding(.top, Spacing.space40)
    }

    private var goal: some View {
        questionPage(title: "What are you working toward?") {
            ForEach(GoalType.allCases) { goal in
                SelectableCard(
                    title: goal.title,
                    subtitle: goal.subtitle,
                    systemImage: goal.systemImage,
                    isSelected: viewModel.draft.goalType == goal
                ) {
                    viewModel.draft.goalType = goal
                }
            }
        }
    }

    private var units: some View {
        questionPage(title: "Which units do you prefer?") {
            Picker("Units", selection: $viewModel.draft.unitSystem) {
                Text("US (lb, ft/in)").tag(UnitSystem.us)
                Text("Metric (kg, cm)").tag(UnitSystem.metric)
            }
            .pickerStyle(.segmented)
        }
    }

    private var age: some View {
        questionPage(title: "How old are you?") {
            TextField("Age", text: $viewModel.ageText)
                .keyboardType(.numberPad)
                .textFieldStyle(OnboardingFieldStyle())
            if viewModel.isUnder18 {
                Text("Under 18: we’ll use tracking-only / manual targets — no weight-change prescriptions.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var height: some View {
        questionPage(title: "What’s your height?") {
            if viewModel.draft.unitSystem == .metric {
                TextField("cm", text: $viewModel.heightCmText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(OnboardingFieldStyle())
            } else {
                HStack {
                    Stepper("\(viewModel.heightFeet) ft", value: $viewModel.heightFeet, in: 4...7)
                    TextField("in", value: $viewModel.heightInches, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(OnboardingFieldStyle())
                        .frame(width: 72)
                }
            }
        }
    }

    private var weight: some View {
        questionPage(title: "Current weight") {
            TextField(
                viewModel.draft.unitSystem == .metric ? "kg" : "lb",
                text: $viewModel.weightText
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(OnboardingFieldStyle())
        }
    }

    private var targetWeight: some View {
        questionPage(title: "Optional target weight") {
            TextField(
                viewModel.draft.unitSystem == .metric ? "kg" : "lb",
                text: $viewModel.targetWeightText
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(OnboardingFieldStyle())
            Text("You can skip this.")
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var formula: some View {
        questionPage(title: "For the calorie estimate, which formula should we use?") {
            ForEach(FormulaSex.allCases) { option in
                SelectableCard(
                    title: option.title,
                    subtitle: nil,
                    systemImage: "function",
                    isSelected: viewModel.draft.formulaSex == option
                ) {
                    viewModel.draft.formulaSex = option
                    if option == .skipManual {
                        viewModel.manualCaloriesText = viewModel.manualCaloriesText.isEmpty ? "2000" : viewModel.manualCaloriesText
                    }
                }
            }
            if viewModel.draft.formulaSex == .skipManual {
                TextField("Daily calories", text: $viewModel.manualCaloriesText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(OnboardingFieldStyle())
            }
        }
    }

    private var activity: some View {
        questionPage(title: "How active are you?") {
            ForEach(ActivityLevel.allCases) { level in
                SelectableCard(
                    title: level.title,
                    subtitle: String(format: "Multiplier %.3g", level.multiplier),
                    systemImage: "figure.walk",
                    isSelected: viewModel.activity == level
                ) {
                    viewModel.activity = level
                    viewModel.draft.activityMultiplier = level.multiplier
                }
            }
        }
    }

    private var pace: some View {
        questionPage(title: "Desired pace") {
            ForEach(PacePreference.allCases) { pace in
                SelectableCard(
                    title: pace.title,
                    subtitle: nil,
                    systemImage: "gauge.with.needle",
                    isSelected: viewModel.pace == pace
                ) {
                    viewModel.pace = pace
                }
            }
        }
    }

    private var macros: some View {
        questionPage(title: "Macro preference") {
            ForEach(MacroPreference.allCases.filter { $0 != .custom }) { pref in
                SelectableCard(
                    title: pref.title,
                    subtitle: ratioLabel(pref),
                    systemImage: "chart.pie",
                    isSelected: viewModel.draft.macroPreference == pref
                ) {
                    viewModel.draft.macroPreference = pref
                }
            }
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: Spacing.space20) {
            Text("Your starting target")
                .font(Typography.screenTitle)
                .foregroundStyle(Color.textPrimary)

            MetricCard(
                title: viewModel.calculated?.isEstimate == true ? "Estimated daily calories" : "Daily calories",
                value: viewModel.editedCaloriesText.isEmpty
                    ? "\(viewModel.calculated?.calories ?? 0)"
                    : viewModel.editedCaloriesText,
                subtitle: "Use this as a starting point. You can change it anytime."
            )

            TextField("Edit calories", text: $viewModel.editedCaloriesText)
                .keyboardType(.numberPad)
                .textFieldStyle(OnboardingFieldStyle())

            let macros = viewModel.displayedMacros
            HStack(spacing: Spacing.space12) {
                macroTile("Protein", "\(macros.protein)g", .macroProtein)
                macroTile("Carbs", "\(macros.carbs)g", .macroCarbs)
                macroTile("Fat", "\(macros.fat)g", .macroFat)
            }

            Text("Nutrition estimates are for informational tracking and may be inaccurate. This app does not provide medical advice.")
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)

            Spacer()
        }
        .padding(Spacing.screenHorizontal)
        .padding(.top, Spacing.space32)
        .onAppear { viewModel.recalculate() }
    }

    private func questionPage<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space20) {
                Text(title)
                    .font(Typography.screenTitle)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, Spacing.space32)
                content()
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.space24)
        }
    }

    private func macroTile(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: Spacing.space4) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(Typography.macroValue)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.space12)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func ratioLabel(_ pref: MacroPreference) -> String {
        let r = pref.ratios
        return "\(Int(r.protein * 100))% P · \(Int(r.carbs * 100))% C · \(Int(r.fat * 100))% F"
    }
}

private struct SelectableCard: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.space12) {
                Image(systemName: systemImage)
                    .foregroundStyle(isSelected ? Color.brandInk : Color.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    Text(title)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.supporting)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.brandPrimary : Color.separator)
            }
            .padding(Spacing.cardPaddingCompact)
            .background(isSelected ? Color.brandPrimary.opacity(0.18) : Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Color.brandPrimary : Color.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Spacing.space16)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Color.separator, lineWidth: 1)
            )
    }
}
