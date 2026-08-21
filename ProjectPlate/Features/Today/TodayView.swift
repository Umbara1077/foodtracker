import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
    private let mealRepository: any MealRepository
    private let targetRepository: any TargetRepository
    private let diary: DiaryService
    private let savedMeals: any SavedMealRepository
    private let mealPlan: any MealPlanRepository
    private let analytics: any AnalyticsClient

    var day: Date = .now
    var target: NutritionTargetSnapshot?
    var meals: [MealRecord] = []
    var frequentMeals: [SavedMealTemplate] = []
    var plannedMeals: [PlannedMeal] = []
    var streak: TrackingStreak = .zero
    var totals: DayNutritionTotals = .zero
    var isLoading = true
    var errorMessage: String?
    var showQuickAdd = false
    var showFoodSearch = false
    var showBarcode = false
    var showLabelScan = false
    var showRecipeImport = false
    var showRecipeBuilder = false
    var showMealPlan = false

    init(
        mealRepository: any MealRepository,
        targetRepository: any TargetRepository,
        diary: DiaryService,
        savedMeals: any SavedMealRepository,
        mealPlan: any MealPlanRepository,
        analytics: any AnalyticsClient
    ) {
        self.mealRepository = mealRepository
        self.targetRepository = targetRepository
        self.diary = diary
        self.savedMeals = savedMeals
        self.mealPlan = mealPlan
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
        let streakStart = calendar.date(byAdding: .day, value: -120, to: calendar.startOfDay(for: day)) ?? day
        do {
            async let targetTask = targetRepository.currentTarget(on: day)
            async let mealsTask = mealRepository.meals(on: day, calendar: calendar)
            async let totalsTask = mealRepository.totals(on: day, calendar: calendar)
            async let frequentTask = savedMeals.frequent(limit: 5)
            async let planTask = mealPlan.plans(on: day, calendar: calendar)
            async let streakTask = mealRepository.dailyTotals(
                from: streakStart,
                to: calendar.startOfDay(for: day),
                calendar: calendar
            )
            target = try await targetTask
            meals = try await mealsTask
            totals = try await totalsTask
            frequentMeals = try await frequentTask
            plannedMeals = MealPlanPreference.isEnabled() ? try await planTask : []
            streak = ProgressMath.trackingStreak(
                dailyTotals: try await streakTask,
                now: day,
                calendar: calendar
            )
            let snapshot = WidgetSnapshotStore.make(target: target, totals: totals)
            WidgetSnapshotStore.save(snapshot)
            TodayLiveActivityController.sync(with: snapshot, calendar: calendar)
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

    func logFrequent(_ template: SavedMealTemplate) async {
        do {
            try await diary.saveMeal(template.makeMeal())
            analytics.track(.mealSaved)
            await load()
        } catch {
            errorMessage = "Could not log meal."
        }
    }

    func deletePlan(_ plan: PlannedMeal) async {
        do {
            try await mealPlan.delete(id: plan.id)
            await load()
        } catch {
            errorMessage = "Could not remove plan."
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
                    savedMeals: environment.savedMeals,
                    mealPlan: environment.mealPlan,
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var correctionMeal: MealRecord?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.space24)
                    } else if PlateLayout.prefersWideSplit(
                        horizontalSizeClass: horizontalSizeClass,
                        width: geo.size.width
                    ) {
                        wideLayout
                    } else {
                        compactLayout
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space24)
                .plateReadableWidth()

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Spacing.screenHorizontal)
                }
            }
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
        .sheet(isPresented: $viewModel.showLabelScan) {
            NutritionLabelScannerView {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $viewModel.showRecipeImport) {
            RecipeURLImportSheet {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $viewModel.showRecipeBuilder) {
            RecipeBuilderSheet {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $viewModel.showMealPlan) {
            MealPlanSheet(initialDay: viewModel.day) {
                Task { await viewModel.load() }
            }
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.space24) {
            hero
            streakChip
            quickActions
            plannedSection
            frequentSection
            mealsSection
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: Spacing.space24) {
            VStack(alignment: .leading, spacing: Spacing.space24) {
                hero
                streakChip
                quickActions
                plannedSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: Spacing.space24) {
                frequentSection
                mealsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

            if MicronutrientPreference.isEnabled() {
                micronutrientsCard
            }
        } else {
            ContentUnavailableView(
                "No target yet",
                systemImage: "target",
                description: Text("Finish onboarding to set your daily calories and macros.")
            )
        }
    }

    private var micronutrientsCard: some View {
        let goals = MicronutrientGoals.default
        let nutrients = viewModel.totals.nutrients
        return VStack(alignment: .leading, spacing: Spacing.space12) {
            Text("Micronutrients")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
            MacroProgressView(
                label: "Fiber",
                current: nutrients.fiber ?? 0,
                goal: goals.fiberGrams,
                unit: "g",
                tint: .brandPrimary
            )
            MacroProgressView(
                label: "Sugar",
                current: nutrients.sugar ?? 0,
                goal: goals.sugarGrams,
                unit: "g",
                tint: .macroCarbs
            )
            MacroProgressView(
                label: "Sodium",
                current: nutrients.sodiumMg ?? 0,
                goal: goals.sodiumMg,
                unit: "mg",
                tint: .macroFat
            )
            Text("Soft daily targets — not medical advice. Values appear when foods include them.")
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var streakChip: some View {
        if viewModel.streak.current > 0 || viewModel.streak.longest > 0 {
            HStack(spacing: Spacing.space12) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    Text(viewModel.streak.title)
                        .font(Typography.supporting.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(viewModel.streak.subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.cardPaddingCompact)
            .background(Color.surfaceSecondary.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.streak.title). \(viewModel.streak.subtitle)")
        }
    }

    private var quickActions: some View {
        VStack(spacing: Spacing.space12) {
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
            }

            HStack(spacing: Spacing.space12) {
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

                Button {
                    viewModel.showLabelScan = true
                } label: {
                    Label("Label", systemImage: "doc.text.viewfinder")
                        .font(Typography.supporting.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.space16)
                        .foregroundStyle(Color.textPrimary)
                        .background(Color.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan nutrition label")
            }

            HStack(spacing: Spacing.space12) {
                Button {
                    viewModel.showRecipeImport = true
                } label: {
                    Label("Recipe URL", systemImage: "link")
                        .font(Typography.supporting.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.space16)
                        .foregroundStyle(Color.textPrimary)
                        .background(Color.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Import recipe from URL")

                Button {
                    viewModel.showRecipeBuilder = true
                } label: {
                    Label("Build recipe", systemImage: "list.bullet.rectangle")
                        .font(Typography.supporting.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.space16)
                        .foregroundStyle(Color.textPrimary)
                        .background(Color.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Build a recipe from ingredients")
            }

            if MealPlanPreference.isEnabled() {
                Button {
                    viewModel.showMealPlan = true
                } label: {
                    Label("Plan a meal", systemImage: "calendar.badge.plus")
                        .font(Typography.supporting.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.space16)
                        .foregroundStyle(Color.textPrimary)
                        .background(Color.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Plan a meal for today or later")
            }
        }
    }

    @ViewBuilder
    private var plannedSection: some View {
        if MealPlanPreference.isEnabled() {
            VStack(alignment: .leading, spacing: Spacing.space12) {
                Text("Planned")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Color.textPrimary)
                if viewModel.plannedMeals.isEmpty {
                    Text("Sketch tonight’s dinner or tomorrow’s lunch — planning stays local and optional.")
                        .font(Typography.supporting)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(viewModel.plannedMeals) { plan in
                        HStack(spacing: Spacing.space12) {
                            VStack(alignment: .leading, spacing: Spacing.space4) {
                                Text(plan.title)
                                    .font(Typography.supporting.weight(.semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(plan.mealType.title)
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Button("Remove") {
                                Task { await viewModel.deletePlan(plan) }
                            }
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityLabel("Remove planned \(plan.title)")
                        }
                        .padding(Spacing.cardPaddingCompact)
                        .background(Color.surfaceSecondary.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var frequentSection: some View {
        if !viewModel.frequentMeals.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.space12) {
                Text("Frequent")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Color.textPrimary)
                Text("Tap to log again — no scan needed.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)

                ForEach(viewModel.frequentMeals) { template in
                    Button {
                        Task { await viewModel.logFrequent(template) }
                    } label: {
                        HStack(spacing: Spacing.space12) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(Color.brandPrimary)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.space4) {
                                Text(template.title)
                                    .font(Typography.body.weight(.semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("Logged \(template.useCount)× · \(Int(template.nutrients.calories.rounded())) cal")
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Text("Log")
                                .font(Typography.supporting.weight(.semibold))
                                .foregroundStyle(Color.brandInk)
                                .padding(.horizontal, Spacing.space12)
                                .padding(.vertical, Spacing.space8)
                                .background(Color.brandPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        }
                        .padding(Spacing.cardPaddingCompact)
                        .background(Color.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log \(template.title), \(Int(template.nutrients.calories.rounded())) calories")
                }
            }
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
