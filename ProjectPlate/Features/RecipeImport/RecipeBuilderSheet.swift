import SwiftUI

struct RecipeBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var title = ""
    @State private var servingsText = "2"
    @State private var logServingsText = "1"
    @State private var mealType: MealType = .inferred()
    @State private var lines: [RecipeBuilderLine] = [
        RecipeBuilderLine(text: ""),
        RecipeBuilderLine(text: ""),
        RecipeBuilderLine(text: ""),
    ]
    @State private var estimated: RecipeImportDraft?
    @State private var isEstimating = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var warning: String?

    var onSaved: (() -> Void)?

    private var filledIngredients: Int {
        lines.filter { !$0.isBlank }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $title)
                    TextField("Recipe servings", text: $servingsText)
                        .keyboardType(.decimalPad)
                    TextField("Servings to log", text: $logServingsText)
                        .keyboardType(.decimalPad)
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                Section("Ingredients") {
                    ForEach($lines) { $line in
                        TextField("e.g. 1 cup cooked rice", text: $line.text)
                    }
                    .onDelete { indexSet in
                        lines.remove(atOffsets: indexSet)
                        if lines.isEmpty {
                            lines = [RecipeBuilderLine()]
                        }
                    }
                    Button("Add ingredient") {
                        lines.append(RecipeBuilderLine())
                    }
                    Button("Estimate nutrition") {
                        Task { await estimate() }
                    }
                    .disabled(isEstimating || filledIngredients == 0)
                }

                if isEstimating {
                    Section {
                        ProgressView("Estimating from catalog…")
                    }
                }

                if let estimated {
                    Section("Estimated totals (full recipe)") {
                        LabeledContent("Calories", value: "\(Int(estimated.nutrients.calories.rounded()))")
                        LabeledContent("Protein", value: String(format: "%.0fg", estimated.nutrients.protein))
                        LabeledContent("Carbs", value: String(format: "%.0fg", estimated.nutrients.carbs))
                        LabeledContent("Fat", value: String(format: "%.0fg", estimated.nutrients.fat))
                        Text("Best-effort catalog matches — review before saving.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                if let warning {
                    Section {
                        Text(warning)
                            .font(Typography.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(Typography.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Build recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || isEstimating || filledIngredients == 0)
                }
            }
        }
    }

    private func estimate() async {
        isEstimating = true
        errorMessage = nil
        warning = nil
        defer { isEstimating = false }
        let servings = Double(servingsText.replacingOccurrences(of: ",", with: ".")) ?? 2
        let draft = RecipeBuilder.draft(title: title, servings: servings, lines: lines)
        guard !draft.ingredients.isEmpty else {
            errorMessage = "Add at least one ingredient."
            return
        }
        do {
            let estimator = RecipeBuilderEstimator(nutritionRepository: environment.nutritionRepository)
            let result = try await estimator.estimate(draft: draft)
            estimated = result
            if result.nutrients.calories <= 0 {
                warning = "No catalog matches yet — you can still save and adjust later."
            }
        } catch {
            errorMessage = "Could not estimate nutrition."
            environment.crashReporter.record(error: error, context: "recipeBuilder.estimate")
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let servings = Double(servingsText.replacingOccurrences(of: ",", with: ".")) ?? 2
        var draft = estimated ?? RecipeBuilder.draft(title: title, servings: servings, lines: lines)
        if estimated == nil {
            do {
                let estimator = RecipeBuilderEstimator(nutritionRepository: environment.nutritionRepository)
                draft = try await estimator.estimate(draft: draft)
            } catch {
                errorMessage = "Could not estimate nutrition."
                return
            }
        }
        guard !draft.ingredients.isEmpty else {
            errorMessage = "Add at least one ingredient."
            return
        }
        let logServings = Double(logServingsText.replacingOccurrences(of: ",", with: ".")) ?? 1
        let meal = RecipeBuilder.makeMeal(
            from: draft,
            mealType: mealType,
            logServings: max(logServings, 0.25)
        )
        do {
            try await environment.diary.saveMeal(meal)
            environment.analytics.track(.mealSaved)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Could not save meal."
            environment.crashReporter.record(error: error, context: "recipeBuilder.save")
        }
    }
}
