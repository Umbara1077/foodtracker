import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    private let mealRepository: any MealRepository
    private let targetRepository: any TargetRepository
    private let analytics: any AnalyticsClient

    var selectedDay: Date = .now
    var weekStart: Date = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now
    var meals: [MealRecord] = []
    var totals: DayNutritionTotals = .zero
    var target: NutritionTargetSnapshot?
    var daysWithMeals: Set<DateComponents> = []
    var isLoading = true
    var errorMessage: String?
    var showQuickAdd = false

    init(
        mealRepository: any MealRepository,
        targetRepository: any TargetRepository,
        analytics: any AnalyticsClient
    ) {
        self.mealRepository = mealRepository
        self.targetRepository = targetRepository
        self.analytics = analytics
    }

    var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
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
            try await mealRepository.delete(id: meal.id)
            analytics.track(.mealDeleted)
            await load()
        } catch {
            errorMessage = "Could not delete meal."
        }
    }

    func duplicateToToday(_ meal: MealRecord) async {
        var copy = meal
        copy.id = UUID()
        copy.eatenAt = .now
        copy.inputMethod = .duplicated
        copy.createdAt = .now
        copy.updatedAt = .now
        do {
            try await mealRepository.save(copy)
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
        }
        .task {
            if viewModel == nil {
                let vm = HistoryViewModel(
                    mealRepository: environment.mealRepository,
                    targetRepository: environment.targetRepository,
                    analytics: environment.analytics
                )
                viewModel = vm
                await vm.load()
            }
        }
    }
}

private struct HistoryContent: View {
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
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
                        ContentUnavailableView(
                            "No meals",
                            systemImage: "calendar",
                            description: Text("Nothing logged on this day.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        Section("Meals") {
                            ForEach(viewModel.meals) { meal in
                                MealRowView(meal: meal)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button("Delete", role: .destructive) {
                                            Task { await viewModel.deleteMeal(meal) }
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button("To today") {
                                            Task { await viewModel.duplicateToToday(meal) }
                                        }
                                        .tint(Color.brandPrimary)
                                    }
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.red).font(Typography.caption)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
