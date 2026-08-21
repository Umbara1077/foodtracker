import Charts
import SwiftUI

@MainActor
@Observable
final class ProgressViewModel {
    private let weightRepository: any WeightRepository
    private let mealRepository: any MealRepository
    private let targetRepository: any TargetRepository
    private let profileRepository: any ProfileRepository

    var range: ProgressRange = .days30
    var entries: [WeightEntry] = []
    var latest: WeightEntry?
    var consistency: ConsistencyStats = .zero
    var weeklyDigest: WeeklyDigest = .empty
    var streak: TrackingStreak = .zero
    var adaptiveSuggestion: AdaptiveGoalSuggestion?
    var coachInsights: [CoachInsight] = []
    var weeklyChallenges: [WeeklyChallenge] = []
    var unitSystem: UnitSystem = .metric
    var isLoading = true
    var errorMessage: String?
    var adaptiveMessage: String?
    var showAddWeight = false
    var isApplyingAdaptive = false
    private var goalType: GoalType = .maintainWeight

    init(
        weightRepository: any WeightRepository,
        mealRepository: any MealRepository,
        targetRepository: any TargetRepository,
        profileRepository: any ProfileRepository
    ) {
        self.weightRepository = weightRepository
        self.mealRepository = mealRepository
        self.targetRepository = targetRepository
        self.profileRepository = profileRepository
    }

    var weightChangeKg: Double? {
        ProgressMath.weightChangeKg(entries: entries)
    }

    func load(calendar: Calendar = .current) async {
        isLoading = true
        errorMessage = nil
        let end = Date()
        let start = range.startDate(relativeTo: end, calendar: calendar)
        let weekEnd = calendar.startOfDay(for: end)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
        let streakStart = calendar.date(byAdding: .day, value: -120, to: weekEnd) ?? weekEnd
        let adaptiveStart = calendar.date(byAdding: .day, value: -45, to: weekEnd) ?? weekEnd
        do {
            async let weightTask = weightRepository.entries(from: start, to: end)
            async let latestTask = weightRepository.latest()
            async let profileTask = profileRepository.loadProfile()
            async let targetTask = targetRepository.currentTarget(on: end)
            async let dailyTask = mealRepository.dailyTotals(from: start, to: end, calendar: calendar)
            async let weekMealsTask = mealRepository.dailyTotals(from: weekStart, to: weekEnd, calendar: calendar)
            async let weekWeightsTask = weightRepository.entries(from: weekStart, to: end)
            async let streakMealsTask = mealRepository.dailyTotals(from: streakStart, to: weekEnd, calendar: calendar)
            async let adaptiveWeightsTask = weightRepository.entries(from: adaptiveStart, to: end)
            async let adaptiveMealsTask = mealRepository.dailyTotals(from: adaptiveStart, to: weekEnd, calendar: calendar)

            entries = try await weightTask
            latest = try await latestTask
            let profile = try await profileTask
            unitSystem = profile?.unitSystem ?? .metric
            goalType = profile?.goalType ?? .maintainWeight
            let target = try await targetTask
            let daily = try await dailyTask
            let weekMeals = try await weekMealsTask
            consistency = ProgressMath.consistency(dailyTotals: daily, target: target)
            weeklyDigest = ProgressMath.weeklyDigest(
                dailyTotals: weekMeals,
                weightEntries: try await weekWeightsTask,
                target: target,
                weekStart: weekStart,
                weekEnd: weekEnd
            )
            streak = ProgressMath.trackingStreak(
                dailyTotals: try await streakMealsTask,
                now: end,
                calendar: calendar
            )
            adaptiveSuggestion = makeAdaptiveSuggestion(
                profile: profile,
                target: target,
                weights: try await adaptiveWeightsTask,
                meals: try await adaptiveMealsTask
            )
            if CoachInsightPreference.isEnabled() {
                coachInsights = CoachInsightEngine.insights(
                    digest: weeklyDigest,
                    streak: streak,
                    consistency: consistency,
                    goalType: goalType
                )
            } else {
                coachInsights = []
            }
            if ChallengePreference.isEnabled() {
                weeklyChallenges = ChallengeEngine.challenges(
                    digest: weeklyDigest,
                    dailyTotals: weekMeals,
                    target: target
                )
            } else {
                weeklyChallenges = []
            }
        } catch {
            errorMessage = "Could not load progress."
        }
        isLoading = false
    }

    func applyAdaptiveSuggestion() async {
        guard let suggestion = adaptiveSuggestion else { return }
        isApplyingAdaptive = true
        adaptiveMessage = nil
        defer { isApplyingAdaptive = false }
        do {
            let snapshot = AdaptiveGoalEngine.makeTarget(from: suggestion)
            try await targetRepository.saveTarget(snapshot)
            AdaptiveGoalPreference.clearDismissal()
            adaptiveSuggestion = nil
            adaptiveMessage = "Updated today’s calorie target to \(snapshot.calories)."
            await load()
        } catch {
            adaptiveMessage = "Could not save the new target."
        }
    }

    func dismissAdaptiveSuggestion() {
        AdaptiveGoalPreference.dismiss(forDays: 14)
        adaptiveSuggestion = nil
        adaptiveMessage = "Suggestion hidden for two weeks."
    }

    private func makeAdaptiveSuggestion(
        profile: UserProfile?,
        target: NutritionTargetSnapshot?,
        weights: [WeightEntry],
        meals: [(date: Date, totals: DayNutritionTotals)]
    ) -> AdaptiveGoalSuggestion? {
        guard AdaptiveGoalPreference.isEnabled() else { return nil }
        guard !AdaptiveGoalPreference.isDismissed() else { return nil }
        guard let profile, let target else { return nil }
        let daysLogged = meals.filter { $0.totals.mealCount > 0 }.count
        return AdaptiveGoalEngine.suggestion(
            goalType: profile.goalType,
            macroPreference: profile.macroPreference,
            currentTarget: target,
            weightEntries: weights,
            daysLoggedRecently: daysLogged
        )
    }

    func displayWeight(_ kg: Double) -> String {
        if unitSystem == .us {
            let lbs = kg * 2.2046226218
            return String(format: "%.1f lb", lbs)
        }
        return String(format: "%.1f kg", kg)
    }

    func displayChange(_ deltaKg: Double) -> String {
        let sign = deltaKg > 0 ? "+" : ""
        if unitSystem == .us {
            return String(format: "%@%.1f lb", sign, deltaKg * 2.2046226218)
        }
        return String(format: "%@%.1f kg", sign, deltaKg)
    }
}

struct ProgressViewScreen: View {
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: ProgressViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ProgressContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel?.showAddWeight = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Log weight")
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = ProgressViewModel(
                    weightRepository: environment.weightRepository,
                    mealRepository: environment.mealRepository,
                    targetRepository: environment.targetRepository,
                    profileRepository: environment.profileRepository
                )
                viewModel = vm
                await vm.load()
            }
        }
    }
}

private struct ProgressContent: View {
    @Bindable var viewModel: ProgressViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space24) {
                rangePicker
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    weeklyDigestCard
                    challengesCard
                    coachInsightsCard
                    streakCard
                    adaptiveGoalCard
                    weightCard
                    consistencyCard
                }
                if let adaptiveMessage = viewModel.adaptiveMessage {
                    Text(adaptiveMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                }
                Text("Charts show your logged data only. They don’t explain why weight changed.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.space24)
        }
        .sheet(isPresented: $viewModel.showAddWeight) {
            AddWeightSheet(unitSystem: viewModel.unitSystem) {
                Task { await viewModel.load() }
            }
        }
        .onChange(of: viewModel.range) { _, _ in
            Task { await viewModel.load() }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $viewModel.range) {
            ForEach(ProgressRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Progress range")
    }

    private var weeklyDigestCard: some View {
        let digest = viewModel.weeklyDigest
        return VStack(alignment: .leading, spacing: Spacing.space16) {
            Text("This week")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)
            Text(digest.highlight)
                .font(Typography.supporting)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.space12) {
                digestStat(
                    title: "Days",
                    value: "\(digest.daysTracked)",
                    subtitle: "tracked"
                )
                digestStat(
                    title: "Meals",
                    value: "\(digest.mealsLogged)",
                    subtitle: "logged"
                )
                digestStat(
                    title: "Avg cal",
                    value: digest.daysTracked == 0 ? "—" : "\(Int(digest.averageCalories.rounded()))",
                    subtitle: digest.targetCalories > 0
                        ? "of \(Int(digest.targetCalories))"
                        : "per day"
                )
            }

            if digest.daysTracked > 0 {
                MacroProgressView(
                    label: "Avg protein this week",
                    current: digest.averageProtein,
                    goal: max(digest.targetProtein, 1),
                    unit: "g",
                    tint: .macroProtein
                )
            }

            if MicronutrientPreference.isEnabled(),
               digest.averageFiber != nil || digest.averageSugar != nil || digest.averageSodiumMg != nil {
                let goals = MicronutrientGoals.default
                Text("Avg micronutrients")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                if let fiber = digest.averageFiber {
                    MacroProgressView(
                        label: "Fiber",
                        current: fiber,
                        goal: goals.fiberGrams,
                        unit: "g",
                        tint: .brandPrimary
                    )
                }
                if let sugar = digest.averageSugar {
                    MacroProgressView(
                        label: "Sugar",
                        current: sugar,
                        goal: goals.sugarGrams,
                        unit: "g",
                        tint: .macroCarbs
                    )
                }
                if let sodium = digest.averageSodiumMg {
                    MacroProgressView(
                        label: "Sodium",
                        current: sodium,
                        goal: goals.sodiumMg,
                        unit: "mg",
                        tint: .macroFat
                    )
                }
            }
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly digest. \(digest.highlight)")
    }

    @ViewBuilder
    private var challengesCard: some View {
        if !viewModel.weeklyChallenges.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.space16) {
                Text("This week’s challenges")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Color.textPrimary)
                Text("Optional goals — skip anytime. No streaks are lost for pausing.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(viewModel.weeklyChallenges) { challenge in
                    VStack(alignment: .leading, spacing: Spacing.space8) {
                        HStack {
                            Text(challenge.title)
                                .font(Typography.supporting.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("\(challenge.current)/\(challenge.goal)")
                                .font(Typography.macroValue)
                                .foregroundStyle(Color.textPrimary)
                        }
                        Text(challenge.detail)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.surfaceSecondary)
                                Capsule()
                                    .fill(challenge.isComplete ? Color.brandPrimary : Color.macroProtein)
                                    .frame(width: geo.size.width * challenge.progressFraction)
                            }
                        }
                        .frame(height: 6)
                        .accessibilityHidden(true)
                        Text(challenge.statusLine)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(challenge.title), \(challenge.current) of \(challenge.goal). \(challenge.statusLine)")
                }
            }
            .padding(Spacing.cardPaddingCompact)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    @ViewBuilder
    private var coachInsightsCard: some View {
        if !viewModel.coachInsights.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.space16) {
                Text("Coach")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Color.textPrimary)
                Text("Local tips from your recent logging — not medical advice.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                ForEach(viewModel.coachInsights) { tip in
                    VStack(alignment: .leading, spacing: Spacing.space4) {
                        Text(tip.title)
                            .font(Typography.supporting.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(tip.body)
                            .font(Typography.supporting)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(tip.title). \(tip.body)")
                }
            }
            .padding(Spacing.cardPaddingCompact)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func digestStat(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(Typography.macroValue)
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakCard: some View {
        let streak = viewModel.streak
        return VStack(alignment: .leading, spacing: Spacing.space12) {
            Text("Tracking streak")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)
            Text(streak.title)
                .font(Typography.heroNumeric(36))
                .foregroundStyle(Color.textPrimary)
            Text(streak.subtitle)
                .font(Typography.supporting)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if streak.longest > 0 {
                Text("Best: \(streak.longest) day\(streak.longest == 1 ? "" : "s")")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak.title). \(streak.subtitle)")
    }

    @ViewBuilder
    private var adaptiveGoalCard: some View {
        if let suggestion = viewModel.adaptiveSuggestion {
            VStack(alignment: .leading, spacing: Spacing.space12) {
                Text("Adaptive goal")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Color.textPrimary)
                Text(suggestion.title)
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(suggestion.detail)
                    .font(Typography.supporting)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(suggestion.currentCalories) → \(suggestion.suggestedCalories) cal")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                HStack(spacing: Spacing.space12) {
                    Button("Use \(suggestion.suggestedCalories) cal") {
                        Task { await viewModel.applyAdaptiveSuggestion() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                    .disabled(viewModel.isApplyingAdaptive)
                    Button("Not now") {
                        viewModel.dismissAdaptiveSuggestion()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isApplyingAdaptive)
                }
            }
            .padding(Spacing.cardPaddingCompact)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(suggestion.title). \(suggestion.detail)")
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: Spacing.space16) {
            Text("Weight")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)

            HStack(alignment: .firstTextBaseline) {
                if let latest = viewModel.latest {
                    Text(viewModel.displayWeight(latest.kilograms))
                        .font(Typography.heroNumeric(44))
                        .foregroundStyle(Color.textPrimary)
                } else {
                    Text("—")
                        .font(Typography.heroNumeric(44))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                if let change = viewModel.weightChangeKg {
                    Text(viewModel.displayChange(change))
                        .font(Typography.supporting.weight(.semibold))
                        .foregroundStyle(change <= 0 ? Color.brandPrimary : Color.textSecondary)
                } else {
                    Text("Log 2+ entries to see change")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if viewModel.entries.count >= 2 {
                Chart(viewModel.entries) { entry in
                    LineMark(
                        x: .value("Date", entry.recordedAt),
                        y: .value("Weight", chartY(entry.kilograms))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.brandPrimary)
                    PointMark(
                        x: .value("Date", entry.recordedAt),
                        y: .value("Weight", chartY(entry.kilograms))
                    )
                    .foregroundStyle(Color.brandInk)
                }
                .chartYAxisLabel(viewModel.unitSystem == .us ? "lb" : "kg")
                .frame(height: 180)
                .accessibilityLabel("Weight trend chart")
                .accessibilityHidden(accessibilityReduceMotion)
                .opacity(accessibilityReduceMotion ? 0.85 : 1)
            } else {
                ContentUnavailableView(
                    "No weight trend yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Log your weight to see a \(viewModel.range.title) chart.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.space16)
            }

            PrimaryButton(title: "Log weight") {
                viewModel.showAddWeight = true
            }
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.space16) {
            Text("Consistency")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)

            Text("\(viewModel.consistency.daysLogged) days logged in this range")
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)

            MacroProgressView(
                label: "Avg calories vs target",
                current: viewModel.consistency.averageCalories,
                goal: max(viewModel.consistency.targetCalories, 1),
                unit: "cal",
                tint: .brandPrimary
            )
            MacroProgressView(
                label: "Avg protein vs target",
                current: viewModel.consistency.averageProtein,
                goal: max(viewModel.consistency.targetProtein, 1),
                unit: "g",
                tint: .macroProtein
            )
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func chartY(_ kg: Double) -> Double {
        viewModel.unitSystem == .us ? kg * 2.2046226218 : kg
    }
}

struct AddWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    var unitSystem: UnitSystem
    var onSaved: (() -> Void)?

    @State private var weightText = ""
    @State private var note = ""
    @State private var recordedAt = Date()
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    TextField(unitSystem == .us ? "Pounds" : "Kilograms", text: $weightText)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $recordedAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note (optional)", text: $note)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")), value > 0 else {
            errorMessage = "Enter a valid weight."
            return
        }
        isSaving = true
        errorMessage = nil
        let kg = unitSystem == .us ? value / 2.2046226218 : value
        let entry = WeightEntry(
            recordedAt: recordedAt,
            kilograms: kg,
            note: note.isEmpty ? nil : note,
            source: .local
        )
        do {
            try await environment.diary.saveWeight(entry)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Could not save weight."
            isSaving = false
        }
    }
}

#Preview {
    ProgressViewScreen()
        .environment(\.appEnvironment, .preview)
}
