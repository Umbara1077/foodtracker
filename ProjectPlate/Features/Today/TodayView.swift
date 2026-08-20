import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
    private let mealRepository: any MealRepository
    private let targetRepository: any TargetRepository

    var target: NutritionTargetSnapshot?
    var eatenCalories: Double = 0
    var eatenProtein: Double = 0
    var eatenCarbs: Double = 0
    var eatenFat: Double = 0
    var isLoading = true
    var errorMessage: String?

    init(mealRepository: any MealRepository, targetRepository: any TargetRepository) {
        self.mealRepository = mealRepository
        self.targetRepository = targetRepository
    }

    var remainingCalories: Int {
        let goal = Double(target?.calories ?? 0)
        return Int((goal - eatenCalories).rounded())
    }

    var isOverTarget: Bool {
        remainingCalories < 0
    }

    func load(day: Date = .now, calendar: Calendar = .current) async {
        isLoading = true
        errorMessage = nil
        do {
            async let targetTask = targetRepository.currentTarget(on: day)
            async let mealsTask = mealRepository.meals(on: day, calendar: calendar)
            target = try await targetTask
            let meals = try await mealsTask
            eatenCalories = meals.reduce(0) { $0 + $1.calories }
            // Phase 2 will supply per-macro meal totals; keep zeros for now.
            eatenProtein = 0
            eatenCarbs = 0
            eatenFat = 0
        } catch {
            errorMessage = "Could not load today’s targets."
        }
        isLoading = false
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
        }
        .task {
            if viewModel == nil {
                let vm = TodayViewModel(
                    mealRepository: environment.mealRepository,
                    targetRepository: environment.targetRepository
                )
                viewModel = vm
                await vm.load()
            }
        }
    }
}

private struct TodayContent: View {
    @Bindable var viewModel: TodayViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let target = viewModel.target {
                    MetricCard(
                        title: viewModel.isOverTarget ? "Calories over target" : "Calories remaining",
                        value: formatNumber(abs(viewModel.remainingCalories)),
                        subtitle: "\(formatNumber(Int(viewModel.eatenCalories.rounded()))) eaten · \(formatNumber(target.calories)) goal"
                    )

                    VStack(alignment: .leading, spacing: Spacing.space12) {
                        MacroProgressView(
                            label: "Protein",
                            current: viewModel.eatenProtein,
                            goal: Double(target.proteinGrams),
                            unit: "g",
                            tint: .macroProtein
                        )
                        MacroProgressView(
                            label: "Carbs",
                            current: viewModel.eatenCarbs,
                            goal: Double(target.carbGrams),
                            unit: "g",
                            tint: .macroCarbs
                        )
                        MacroProgressView(
                            label: "Fat",
                            current: viewModel.eatenFat,
                            goal: Double(target.fatGrams),
                            unit: "g",
                            tint: .macroFat
                        )
                    }
                    .padding(Spacing.cardPaddingCompact)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                    emptyState
                } else {
                    ContentUnavailableView(
                        "No target yet",
                        systemImage: "target",
                        description: Text("Finish onboarding to set your daily calories and macros.")
                    )
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
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.space16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)
            Text("Your first meal takes one photo.")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("Manual logging arrives in Phase 2. Use Scan when you’re ready to try the camera shell.")
                .font(Typography.supporting)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.space32)
        .background(Color.surfaceSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func formatNumber(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}

#Preview {
    TodayView()
        .environment(\.appEnvironment, .preview)
}
