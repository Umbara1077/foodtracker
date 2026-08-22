import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    private let mealRepository: any MealRepository
    private let targetRepository: any TargetRepository
    private let diary: DiaryService
    private let analytics: any AnalyticsClient

    @Published var selectedDay: Date = .now
    @Published var weekStart: Date = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now
    @Published var meals: [MealRecord] = []
    @Published var totals: DayNutritionTotals = .zero
    @Published var target: NutritionTargetSnapshot?
    @Published var daysWithMeals: Set<DateComponents> = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showQuickAdd = false
    @Published var undoMeal: MealRecord?
    @Published var undoBannerMessage: String?
    @Published var searchQuery = ""

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

    var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var filteredMeals: [MealRecord] {
        MealSearch.filter(meals, query: searchQuery)
    }

    func load(calendar: Calendar = .current) async {
        isLoading = true
        errorMessage = nil
        do {
            let rangeStart = weekStart
            let rangeEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            async let mealsTask = mealRepository.meals(on: selectedDay, calendar: calendar)
            async let totalsTask = mealRepository.totals(on: selectedDay, calendar: calendar)
            async let targetTask = targetRepository.currentTarget(on: selectedDay)
            async let dotsTask = mealRepository.daysWithMeals(from: rangeStart, to: rangeEnd, calendar: calendar)
            meals = try await mealsTask
            totals = try await totalsTask
            target = try await targetTask
            daysWithMeals = try await dotsTask
        } catch {
            errorMessage = "Could not load history."
        }
        isLoading = false
    }

    func selectDay(_ day: Date) async {
        selectedDay = day
        searchQuery = ""
        await load()
    }

    func shiftWeek(by delta: Int) async {
        if let next = Calendar.current.date(byAdding: .day, value: delta * 7, to: weekStart) {
            weekStart = next
            await load()
        }
    }

    func deleteMeal(_ meal: MealRecord) async {
        do {
            try await diary.deleteMeal(meal)
            undoMeal = meal
            undoBannerMessage = MealDeleteUndo.bannerMessage(for: meal)
            analytics.track(.mealDeleted)
            PlateHaptics.play(.mealDeleted)
            await load()
        } catch {
            errorMessage = "Could not delete meal."
            PlateHaptics.play(.warning)
        }
    }

    func undoDelete() async {
        guard let meal = undoMeal else { return }
        do {
            try await diary.saveMeal(meal)
            undoMeal = nil
            undoBannerMessage = nil
            analytics.track(.mealSaved)
            PlateHaptics.play(.mealSaved)
            await load()
        } catch {
            errorMessage = "Could not undo delete."
            PlateHaptics.play(.warning)
        }
    }

    func dismissUndoBanner() {
        undoMeal = nil
        undoBannerMessage = nil
    }

    func duplicateToToday(_ meal: MealRecord) async {
        @Published var copy = meal
        copy.id = UUID()
        copy.eatenAt = .now
        copy.inputMethod = .duplicated
        copy.healthKitAnchors = nil
        copy.createdAt = .now
        copy.updatedAt = .now
        do {
            try await diary.saveMeal(copy)
            analytics.track(.mealSaved)
            selectedDay = .now
            weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now
            await load()
        } catch {
            errorMessage = "Could not duplicate meal."
        }
    }

    func hasMeals(on day: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        return daysWithMeals.contains(comps)
    }

    var daySummaryShareText: String {
        DaySummaryShare.plainText(
            day: selectedDay,
            totals: totals,
            target: target,
            meals: meals
        )
    }

    func noteDaySummaryShared() {
        analytics.track(.daySummaryShared)
    }
}

struct HistoryView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    HistoryContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("History")
            .toolbar {
                if let viewModel, !viewModel.meals.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
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
        .task {
            if viewModel == nil {
                let vm = HistoryViewModel(
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

private struct HistoryContent: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var correctionMeal: MealRecord?
    @State private var editingMeal: MealRecord?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: Spacing.space16) {
                dayStrip
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: Spacing.space8) {
                                Text(viewModel.selectedDay.formatted(date: .complete, time: .omitted))
                                    .font(Typography.sectionHeading)
                                Text("\(Int(viewModel.totals.nutrients.calories.rounded())) cal · P \(Int(viewModel.totals.nutrients.protein.rounded())) · C \(Int(viewModel.totals.nutrients.carbs.rounded())) · F \(Int(viewModel.totals.nutrients.fat.rounded()))")
                                    .font(Typography.supporting)
                                    .foregroundStyle(Color.textSecondary)
                                if let target = viewModel.target {
                                    Text("Target \(target.calories) cal")
                                        .font(Typography.caption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .listRowBackground(Color.surfacePrimary)
                        }

                        if viewModel.meals.isEmpty {
                            PlateEmptyState(
                                "No meals",
                                systemImage: "calendar",
                                description: Text("Nothing logged on this day. Use Log to today from another meal, or add from Today.")
                            )
                            .listRowBackground(Color.clear)
                            .accessibilityLabel("No meals on this day")
                        } else if viewModel.filteredMeals.isEmpty {
                            PlateEmptyState(
                                "No matches",
                                systemImage: "magnifyingglass",
                                description: Text("No meals on this day match “\(viewModel.searchQuery)”.")
                            )
                            .listRowBackground(Color.clear)
                            .accessibilityLabel("No meals match the search")
                        } else {
                            Section(
                                viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Meals"
                                    : "Meals (\(viewModel.filteredMeals.count))"
                            ) {
                                ForEach(viewModel.filteredMeals) { meal in
                                    Button {
                                        editingMeal = meal
                                    } label: {
                                        MealRowView(meal: meal)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button("Delete", role: .destructive) {
                                            Task { await viewModel.deleteMeal(meal) }
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button("Edit") {
                                            editingMeal = meal
                                        }
                                        .tint(Color.brandPrimary)
                                        Button("Correct") {
                                            correctionMeal = meal
                                        }
                                        .tint(Color.brandInk)
                                        Button("To today") {
                                            Task { await viewModel.duplicateToToday(meal) }
                                        }
                                        .tint(Color.brandPrimary)
                                    }
                                    .contextMenu {
                                        Button("Edit") {
                                            editingMeal = meal
                                        }
                                        Button("Send correction") {
                                            correctionMeal = meal
                                        }
                                        Button("Log to today") {
                                            Task { await viewModel.duplicateToToday(meal) }
                                        }
                                        Button("Delete", role: .destructive) {
                                            Task { await viewModel.deleteMeal(meal) }
                                        }
                                    }
                                }
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error).foregroundStyle(Color.statusError).font(Typography.caption)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(
                        text: $viewModel.searchQuery,
                        prompt: "Search this day’s meals"
                    )
                }
            }
            .plateReadableWidth()

            if let message = viewModel.undoBannerMessage {
                UndoDeleteBanner(
                    message: message,
                    onUndo: { Task { await viewModel.undoDelete() } },
                    onDismiss: { viewModel.dismissUndoBanner() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(6))
                    if viewModel.undoBannerMessage == message {
                        viewModel.dismissUndoBanner()
                    }
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
    }

    private var dayStrip: some View {
        VStack(spacing: Spacing.space8) {
            HStack {
                Button {
                    Task { await viewModel.shiftWeek(by: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous week")

                Spacer()
                Text(weekLabel)
                    .font(Typography.supporting.weight(.semibold))
                Spacer()

                Button {
                    Task { await viewModel.shiftWeek(by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next week")
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.space8) {
                    ForEach(viewModel.weekDays, id: \.self) { day in
                        Button {
                            Task { await viewModel.selectDay(day) }
                        } label: {
                            VStack(spacing: Spacing.space4) {
                                Text(day.formatted(.dateTime.weekday(.narrow)))
                                    .font(Typography.caption)
                                Text(day.formatted(.dateTime.day()))
                                    .font(Typography.body.weight(.semibold))
                                Circle()
                                    .fill(viewModel.hasMeals(on: day) ? Color.brandPrimary : Color.clear)
                                    .frame(width: 6, height: 6)
                            }
                            .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDay) ? Color.brandInk : Color.textPrimary)
                            .frame(width: 44, height: 64)
                            .background(
                                Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDay)
                                    ? Color.brandPrimary
                                    : Color.surfacePrimary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
        }
        .padding(.top, Spacing.space8)
    }

    private var weekLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: viewModel.weekStart) ?? viewModel.weekStart
        let startText = viewModel.weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(startText) – \(endText)"
    }
}
