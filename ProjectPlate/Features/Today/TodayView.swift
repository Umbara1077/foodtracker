import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
    private let mealRepository: any MealRepository
    private let targetRepository: any TargetRepository
    private let diary: DiaryService
    private let analytics: any AnalyticsClient

    var day: Date = .now
    var target: NutritionTargetSnapshot?
    var meals: [MealRecord] = []
    var totals: DayNutritionTotals = .zero
    var isLoading = true
    var errorMessage: String?
    var showQuickAdd = false
    var showFoodSearch = false
    var showBarcode = false

    init(
        mealRepository: any MealRepository,
        targetRepository: any TargetRepository,
        diary: DiaryService,
        analytics: any AnalyticsClient
    ) {
        self.mealRepository = mealRepository
        self.targetRepository = targetRepository
        self.diary = diary
        self.analytics = analytics
    }

    var remainingCalories: Int {
        let goal = Double(target?.calories ?? 0)
        return Int((goal - totals.nutrients.calories).rounded())
    }

    var isOverTarget: Bool {
        remainingCalories < 0
    }

    func load(calendar: Calendar = .current) async {
        isLoading = true
        errorMessage = nil
        do {
            async let targetTask = targetRepository.currentTarget(on: day)
            async let mealsTask = mealRepository.meals(on: day, calendar: calendar)
            async let totalsTask = mealRepository.totals(on: day, calendar: calendar)
            target = try await targetTask
            meals = try await mealsTask
            totals = try await totalsTask
        } catch {
            errorMessage = "Could not load today’s diary."
        }
        isLoading = false
    }

    func deleteMeal(_ meal: MealRecord) async {
        do {
            try await diary.deleteMeal(meal)
            analytics.track(.mealDeleted)
            await load()
        } catch {
            errorMessage = "Could not delete meal."
        }
    }

    func duplicateMeal(_ meal: MealRecord) async {
        var copy = meal
        copy.id = UUID()
        copy.eatenAt = .now
        copy.inputMethod = .duplicated
        copy.healthKitAnchors = nil
        copy.createdAt = .now
        copy.updatedAt = .now
        do {
            try await diary.saveMeal(copy)
            analytics.track(.mealSaved)
            await load()
        } catch {
            errorMessage = "Could not duplicate meal."
        }
    }
}

struct TodayView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: TodayViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    TodayContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Today")
            .onAppear {
                if let viewModel {
                    Task { await viewModel.load() }
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = TodayViewModel(
                    mealRepository: environment.mealRepository,
                    targetRepository: environment.targetRepository,
                    diary: environment.diary,
                    analytics: environment.analytics
                )
                viewModel = vm
                await vm.load()
            }
        }
    }
}

private struct TodayContent: View {
    @Bindable var viewModel: TodayViewModel
    @State private var correctionMeal: MealRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    hero
                    quickActions
                    mealsSection
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.space24)
        }
        .sheet(item: $correctionMeal) { meal in
            CorrectionFeedbackView(
                mealTitle: meal.title,
                estimatedCalories: meal.nutrients.calories
            )
        }
        .sheet(isPresented: $viewModel.showQuickAdd) {
            QuickAddSheet {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $viewModel.showFoodSearch) {
            FoodSearchView {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $viewModel.showBarcode) {
            BarcodeFlowView {
                Task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        if let target = viewModel.target {
            MetricCard(
                title: viewModel.isOverTarget ? "Calories over target" : "Calories remaining",
                value: formatNumber(abs(viewModel.remainingCalories)),
                subtitle: "\(formatNumber(Int(viewModel.totals.nutrients.calories.rounded()))) eaten · \(formatNumber(target.calories)) goal"
            )

            VStack(alignment: .leading, spacing: Spacing.space12) {
                MacroProgressView(
                    label: "Protein",
                    current: viewModel.totals.nutrients.protein,
                    goal: Double(target.proteinGrams),
                    unit: "g",
                    tint: .macroProtein
                )
                MacroProgressView(
                    label: "Carbs",
                    current: viewModel.totals.nutrients.carbs,
                    goal: Double(target.carbGrams),
                    unit: "g",
                    tint: .macroCarbs
                )
                MacroProgressView(
                    label: "Fat",
                    current: viewModel.totals.nutrients.fat,
                    goal: Double(target.fatGrams),
                    unit: "g",
                    tint: .macroFat
                )
            }
            .padding(Spacing.cardPaddingCompact)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        } else {
            ContentUnavailableView(
                "No target yet",
                systemImage: "target",
                description: Text("Finish onboarding to set your daily calories and macros.")
            )
        }
    }

    private var quickActions: some View {
        HStack(spacing: Spacing.space12) {
            Button {
                viewModel.showQuickAdd = true
            } label: {
                Label("Quick add", systemImage: "plus.circle.fill")
                    .font(Typography.supporting.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.space16)
                    .foregroundStyle(Color.brandInk)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quick add meal")

            Button {
                viewModel.showFoodSearch = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .font(Typography.supporting.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.space16)
                    .foregroundStyle(Color.textPrimary)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search foods")

            Button {
                viewModel.showBarcode = true
            } label: {
                Label("Barcode", systemImage: "barcode.viewfinder")
                    .font(Typography.supporting.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.space16)
                    .foregroundStyle(Color.textPrimary)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan barcode")
        }
    }

    @ViewBuilder
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.space12) {
            Text("Today’s plate")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)

            if viewModel.meals.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.meals) { meal in
                    MealRowView(meal: meal)
                        .contextMenu {
                            Button("Send correction") {
                                correctionMeal = meal
                            }
                            Button("Log again") {
                                Task { await viewModel.duplicateMeal(meal) }
                            }
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.deleteMeal(meal) }
                            }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.space16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)
            Text("Nothing logged yet.")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)
            Text("Search the food catalog, quick-add a meal you know, or scan a plate.")
                .font(Typography.supporting)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: Spacing.space12) {
                PrimaryButton(title: "Search foods") {
                    viewModel.showFoodSearch = true
                }
                SecondaryButton(title: "Quick add") {
                    viewModel.showQuickAdd = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.space32)
        .background(Color.surfaceSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func formatNumber(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}

struct MealRowView: View {
    let meal: MealRecord

    var body: some View {
        HStack(spacing: Spacing.space12) {
            Text(meal.mealType.title.uppercased())
                .font(Typography.caption)
                .foregroundStyle(Color.brandInk)
                .padding(.horizontal, Spacing.space8)
                .padding(.vertical, Spacing.space4)
                .background(Color.brandPrimary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                .frame(width: 78, alignment: .leading)

            VStack(alignment: .leading, spacing: Spacing.space4) {
                Text(meal.title)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(timeString + " · P \(Int(meal.nutrients.protein.rounded()))g")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(meal.nutrients.calories.rounded()))")
                    .font(Typography.macroValue)
                    .foregroundStyle(Color.textPrimary)
                Text("cal")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meal.title), \(meal.mealType.title), \(Int(meal.nutrients.calories.rounded())) calories")
    }

    private var timeString: String {
        meal.eatenAt.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    TodayView()
        .environment(\.appEnvironment, .preview)
}
