import SwiftUI

struct RecipeURLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var urlText = ""
    @State private var draft: RecipeImportDraft?
    @State private var mealType: MealType = .inferred()
    @State private var logServingsText = "1"
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var warning: String?

    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe link") {
                    TextField("https://…", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("Fetch recipe") {
                        Task { await fetchRecipe() }
                    }
                    .disabled(isLoading || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if isLoading {
                    Section {
                        ProgressView("Reading recipe…")
                    }
                }

                if let draft {
                    Section("Imported") {
                        Text(draft.title)
                            .font(Typography.supporting.weight(.semibold))
                        if let host = draft.sourceURL?.host {
                            Text(host)
                                .font(Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        LabeledContent("Recipe servings", value: String(format: "%.0f", draft.servings))
                        TextField("Servings to log", text: $logServingsText)
                            .keyboardType(.decimalPad)
                        Picker("Meal", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                    }
                    Section("Estimated nutrition (full recipe)") {
                        LabeledContent("Calories", value: "\(Int(draft.nutrients.calories.rounded()))")
                        LabeledContent("Protein", value: String(format: "%.0fg", draft.nutrients.protein))
                        LabeledContent("Carbs", value: String(format: "%.0fg", draft.nutrients.carbs))
                        LabeledContent("Fat", value: String(format: "%.0fg", draft.nutrients.fat))
                        Text("Estimates from catalog matches — review before saving.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    if !draft.ingredients.isEmpty {
                        Section("Ingredients (\(draft.ingredients.count))") {
                            ForEach(Array(draft.ingredients.prefix(12).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(Typography.caption)
                            }
                        }
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
            .navigationTitle("Recipe URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(draft == nil || isSaving || isLoading)
                }
            }
        }
    }

    private func fetchRecipe() async {
        isLoading = true
        errorMessage = nil
        warning = nil
        draft = nil
        defer { isLoading = false }
        let importer = RecipeURLImporter(nutritionRepository: environment.nutritionRepository)
        do {
            let result = try await importer.importRecipe(from: urlText)
            draft = result
            if result.nutrients.calories <= 0 {
                warning = "Couldn’t estimate nutrition. You can still save and edit macros later via Quick Add."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let draft else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let servings = Double(logServingsText.replacingOccurrences(of: ",", with: ".")) ?? 1
        let meal = draft.makeMeal(mealType: mealType, logServings: max(servings, 0.25))
        do {
            try await environment.diary.saveMeal(meal)
            environment.analytics.track(.mealSaved)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Could not save meal."
            environment.crashReporter.record(error: error, context: "recipeURL.save")
        }
    }
}
