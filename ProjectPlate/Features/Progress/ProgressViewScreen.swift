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
    var unitSystem: UnitSystem = .metric
    var isLoading = true
    var errorMessage: String?
    var showAddWeight = false

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
        do {
            async let weightTask = weightRepository.entries(from: start, to: end)
            async let latestTask = weightRepository.latest()
            async let profileTask = profileRepository.loadProfile()
            async let targetTask = targetRepository.currentTarget(on: end)
            async let dailyTask = mealRepository.dailyTotals(from: start, to: end, calendar: calendar)
            async let weekMealsTask = mealRepository.dailyTotals(from: weekStart, to: weekEnd, calendar: calendar)
            async let weekWeightsTask = weightRepository.entries(from: weekStart, to: end)

            entries = try await weightTask
            latest = try await latestTask
            unitSystem = try await profileTask?.unitSystem ?? .metric
            let target = try await targetTask
            let daily = try await dailyTask
            consistency = ProgressMath.consistency(dailyTotals: daily, target: target)
            weeklyDigest = ProgressMath.weeklyDigest(
                dailyTotals: try await weekMealsTask,
                weightEntries: try await weekWeightsTask,
                target: target,
                weekStart: weekStart,
                weekEnd: weekEnd
            )
        } catch {
            errorMessage = "Could not load progress."
        }
        isLoading = false
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
                    weightCard
                    consistencyCard
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
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly digest. \(digest.highlight)")
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
