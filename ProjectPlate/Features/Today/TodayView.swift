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
    var previousDayMealCount = 0
    var copyDayMessage: String?
    var showDayPicker = false

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

    var isViewingToday: Bool {
        TodayDayNavigation.isViewingToday(day)
    }

    var navigationTitle: String {
        TodayDayNavigation.title(for: day)
    }

    func load(calendar: Calendar = .current, now: Date = .now) async {
        isLoading = true
        errorMessage = nil
        let streakAnchor = calendar.startOfDay(for: now)
        let streakStart = calendar.date(byAdding: .day, value: -120, to: streakAnchor) ?? streakAnchor
        do {
            async let targetTask = targetRepository.currentTarget(on: day)
            async let mealsTask = mealRepository.meals(on: day, calendar: calendar)
            async let totalsTask = mealRepository.totals(on: day, calendar: calendar)
            async let frequentTask = savedMeals.frequent(limit: 5)
            async let planTask = mealPlan.plans(on: day, calendar: calendar)
            async let streakTask = mealRepository.dailyTotals(
                from: streakStart,
                to: streakAnchor,
                calendar: calendar
            )
            target = try await targetTask
            meals = try await mealsTask
            totals = try await totalsTask
            frequentMeals = try await frequentTask
            plannedMeals = MealPlanPreference.isEnabled() ? try await planTask : []
            streak = ProgressMath.trackingStreak(
                dailyTotals: try await streakTask,
                now: now,
                calendar: calendar
            )
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: day)) {
                previousDayMealCount = try await mealRepository.meals(on: yesterday, calendar: calendar).count
            } else {
                previousDayMealCount = 0
            }
            // Widget / Live Activity always reflect the real today, never a browsed past day.
            if TodayDayNavigation.isViewingToday(day, now: now, calendar: calendar) {
                let snapshot = WidgetSnapshotStore.make(target: target, totals: totals)
                WidgetSnapshotStore.save(snapshot)
                TodayLiveActivityController.sync(with: snapshot, calendar: calendar)
            }
        } catch {
            errorMessage = "Could not load this day’s diary."
        }
        isLoading = false
    }

    func selectDay(_ newDay: Date, calendar: Calendar = .current, now: Date = .now) async {
        day = TodayDayNavigation.clampToPastOrToday(newDay, now: now, calendar: calendar)
        showDayPicker = false
        await load(calendar: calendar, now: now)
    }

    func jumpToToday(calendar: Calendar = .current, now: Date = .now) async {
        await selectDay(now, calendar: calendar, now: now)
    }

    /// Plain-text day summary for the system share sheet.
    var daySummaryShareText: String {
        DaySummaryShare.plainText(
            day: day,
            totals: totals,
            target: target,
            meals: meals
        )
    }

    func noteDaySummaryShared() {
        analytics.track(.daySummaryShared)
    }

    /// Copies yesterday’s meals onto today, preserving clock times.
    func copyPreviousDay(calendar: Calendar = .current) async {
        copyDayMessage = nil
        errorMessage = nil
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: day)) else {
            errorMessage = "Could not find yesterday."
            return
        }
        do {
            let count = try await DayMealCopy.copyMeals(
                from: yesterday,
                to: day,
                mealRepository: mealRepository,
                diary: diary,
                calendar: calendar
            )
            if count == 0 {
                copyDayMessage = "Nothing to copy from yesterday."
            } else {
                analytics.track(.mealSaved)
                copyDayMessage = "Copied \(count) meal\(count == 1 ? "" : "s") from yesterday."
            }
            await load(calendar: calendar)
        } catch {
            errorMessage = "Could not copy yesterday’s meals."
        }
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
            .navigationTitle(viewModel?.navigationTitle ?? "Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.space12) {
                        if let viewModel, !viewModel.isViewingToday {
                            Button("Today") {
                                Task { await viewModel.jumpToToday() }
                            }
                            .font(Typography.supporting.weight(.semibold))
                            .accessibilityLabel("Jump to today")
                        }
                        if let viewModel {
                            Button {
                                viewModel.showDayPicker = true
                            } label: {
                                Image(systemName: "calendar")
                            }
                            .accessibilityLabel("Choose day")
                        }
                        if let viewModel, !viewModel.meals.isEmpty {
                            ShareLink(item: viewModel.daySummaryShareText) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share day summary")
                            .simultaneousGesture(TapGesture().onEnded {
                                viewModel.noteDaySummaryShared()
                            })
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showDayPicker ?? false },
                set: { viewModel?.showDayPicker = $0 }
            )) {
                if let viewModel {
                    TodayDayPickerSheet(day: viewModel.day) { picked in
                        Task { await viewModel.selectDay(picked) }
                    }
                }
            }
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
    @State private var editingMeal: MealRecord?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                Group {
                    if viewModel.isLoading {
                        TodayLoadingSkeleton()
                            .padding(.vertical, Spacing.space8)
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
                        .foregroundStyle(Color.statusError)
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
        .sheet(item: $editingMeal) { meal in
            MealDetailEditorView(meal: meal) {
                Task { await viewModel.load() }
            }
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
        .alert("Copy day", isPresented: Binding(
            get: { viewModel.copyDayMessage != nil },
            set: { if !$0 { viewModel.copyDayMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.copyDayMessage ?? "")
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.space24) {
            greeting
            hero
            streakChip
            copyYesterdayChip
            quickActions
            plannedSection
            frequentSection
            mealsSection
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: Spacing.space24) {
            VStack(alignment: .leading, spacing: Spacing.space24) {
                greeting
                hero
                streakChip
                copyYesterdayChip
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

    private var greeting: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            if viewModel.isViewingToday {
                Text(TodayGreeting.text())
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text(viewModel.day.formatted(date: .complete, time: .omitted))
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    @ViewBuilder
    private var copyYesterdayChip: some View {
        if viewModel.previousDayMealCount > 0, !viewModel.meals.isEmpty {
            Button {
                Task { await viewModel.copyPreviousDay() }
            } label: {
                HStack(spacing: Spacing.space12) {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.space4) {
                        Text(viewModel.isViewingToday ? "Copy yesterday’s meals" : "Copy previous day’s meals")
                            .font(Typography.supporting.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Adds \(viewModel.previousDayMealCount) meal\(viewModel.previousDayMealCount == 1 ? "" : "s") with that day’s times")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.cardPaddingCompact)
                .background(Color.surfaceSecondary.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Duplicates the previous day's meals onto this day")
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
                tint: .macroFiber
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
            Text(viewModel.isViewingToday ? "Today’s plate" : "This day’s plate")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)

            if viewModel.meals.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.meals) { meal in
                    Button {
                        editingMeal = meal
                    } label: {
                        MealRowView(meal: meal)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") {
                            editingMeal = meal
                        }
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
                if viewModel.previousDayMealCount > 0 {
                    SecondaryButton(
                        title: viewModel.isViewingToday
                            ? "Copy yesterday’s \(viewModel.previousDayMealCount) meals"
                            : "Copy previous day’s \(viewModel.previousDayMealCount) meals"
                    ) {
                        Task { await viewModel.copyPreviousDay() }
                    }
                    .accessibilityHint("Adds copies of the previous day's meals to this day")
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

private struct TodayDayPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date
    let onPick: (Date) -> Void

    init(day: Date, onPick: @escaping (Date) -> Void) {
        _draft = State(initialValue: day)
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.space24) {
                DatePicker(
                    "Day",
                    selection: $draft,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, Spacing.screenHorizontal)
                .accessibilityLabel("Choose diary day")

                PrimaryButton(title: "Show this day") {
                    onPick(draft)
                    dismiss()
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer(minLength: 0)
            }
            .padding(.top, Spacing.space16)
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Choose day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    TodayView()
        .environment(\.appEnvironment, .preview)
}
