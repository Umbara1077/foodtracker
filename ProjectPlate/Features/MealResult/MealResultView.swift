import SwiftUI
import UIKit

struct MealResultView: View {
    @Environment(\.appEnvironment) private var environment

    @State var draft: ReviewableMealDraft
    var onSaved: () -> Void
    var onCancel: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space20) {
                    header
                    totals
                    items
                }
                .padding(Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space20)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Review meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", action: onCancel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Spacing.space8) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.caption)
                            .foregroundStyle(.red)
                    }
                    PrimaryButton(
                        title: "Add to today — \(Int(draft.nutrients.calories.rounded())) cal",
                        isEnabled: !isSaving && !draft.items.isEmpty
                    ) {
                        Task { await save() }
                    }
                }
                .padding(Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space12)
                .background(Color.backgroundPrimary.opacity(0.95))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.space12) {
            HStack {
                Text(draft.mealType.title)
                    .font(Typography.caption.weight(.bold))
                    .padding(.horizontal, Spacing.space12)
                    .padding(.vertical, Spacing.space8)
                    .background(Color.surfaceSecondary)
                    .clipShape(Capsule())
                ConfidencePill(confidence: draft.confidence)
                Spacer()
            }
            TextField("Meal name", text: $draft.title)
                .font(Typography.screenTitle)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: Spacing.space8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(draft.nutrients.calories.rounded()))")
                    .font(Typography.heroNumeric())
                Text("cal")
                    .font(Typography.supporting)
                    .foregroundStyle(Color.textSecondary)
            }
            Text(
                "Estimated \(Int(draft.calorieRangeLow.rounded()))–\(Int(draft.calorieRangeHigh.rounded())) cal"
            )
            .font(Typography.supporting)
            .foregroundStyle(Color.textSecondary)

            HStack(spacing: Spacing.space12) {
                macroCard("Protein", "\(Int(draft.nutrients.protein.rounded()))g", .macroProtein)
                macroCard("Carbs", "\(Int(draft.nutrients.carbs.rounded()))g", .macroCarbs)
                macroCard("Fat", "\(Int(draft.nutrients.fat.rounded()))g", .macroFat)
            }
        }
        .padding(Spacing.cardPaddingLarge)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous))
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: Spacing.space12) {
            Text("What I found")
                .font(Typography.sectionHeading)
            ForEach($draft.items) { $item in
                VStack(alignment: .leading, spacing: Spacing.space8) {
                    HStack {
                        Text(item.displayName)
                            .font(Typography.body.weight(.semibold))
                        Spacer()
                        Text("\(Int(item.nutrients.calories.rounded())) cal")
                            .font(Typography.macroValue)
                    }
                    Text("\(Int(item.grams.rounded())) g · \(item.nutritionSourceLabel)")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    ConfidencePill(confidence: item.confidence)
                    HStack {
                        Text("Portion")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                        Slider(
                            value: $item.grams,
                            in: max(5, item.gramRangeLow * 0.5)...max(item.gramRangeHigh * 1.5, item.grams + 1),
                            step: 5
                        )
                        .onChange(of: item.grams) { _, newValue in
                            item.nutrients = FixtureNutritionDatabase.scale(item.per100g, grams: newValue)
                            item.calorieRangeLow = FixtureNutritionDatabase.scale(item.per100g, grams: item.gramRangeLow).calories
                            item.calorieRangeHigh = FixtureNutritionDatabase.scale(item.per100g, grams: item.gramRangeHigh).calories
                            item.userEdited = true
                        }
                    }
                }
                .padding(Spacing.cardPaddingCompact)
                .background(Color.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
    }

    private func macroCard(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: Spacing.space4) {
            Text(title).font(Typography.caption).foregroundStyle(Color.textSecondary)
            Text(value).font(Typography.macroValue).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.space12)
        .background(Color.surfaceSecondary.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let meal = MealRecord(
            eatenAt: draft.eatenAt,
            mealType: draft.mealType,
            title: draft.title,
            nutrients: draft.nutrients,
            inputMethod: .photoScan
        )
        do {
            try await environment.mealRepository.save(meal)
            environment.analytics.track(.mealSaved)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved()
        } catch {
            errorMessage = "Could not save meal."
            isSaving = false
        }
    }
}
