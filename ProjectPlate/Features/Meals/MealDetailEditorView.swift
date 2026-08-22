import SwiftUI

/// Edit a logged meal (PRODUCT_SPEC §19). Keeps the same meal id so history/sync stay stable.
struct MealDetailEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    let meal: MealRecord
    var onSaved: (() -> Void)?

    @State private var title: String
    @State private var mealType: MealType
    @State private var eatenAt: Date
    @State private var notes: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var fiberText: String
    @State private var sugarText: String
    @State private var sodiumText: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(meal: MealRecord, onSaved: (() -> Void)? = nil) {
        self.meal = meal
        self.onSaved = onSaved
        _title = State(initialValue: meal.title)
        _mealType = State(initialValue: meal.mealType)
        _eatenAt = State(initialValue: meal.eatenAt)
        _notes = State(initialValue: meal.notes ?? "")
        _caloriesText = State(initialValue: Self.numberString(meal.nutrients.calories))
        _proteinText = State(initialValue: Self.numberString(meal.nutrients.protein))
        _carbsText = State(initialValue: Self.numberString(meal.nutrients.carbs))
        _fatText = State(initialValue: Self.numberString(meal.nutrients.fat))
        _fiberText = State(initialValue: meal.nutrients.fiber.map(Self.numberString) ?? "")
        _sugarText = State(initialValue: meal.nutrients.sugar.map(Self.numberString) ?? "")
        _sodiumText = State(initialValue: meal.nutrients.sodiumMg.map(Self.numberString) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    DatePicker("Logged at", selection: $eatenAt)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Nutrition") {
                    TextField("Calories", text: $caloriesText)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $proteinText)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbsText)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fatText)
                        .keyboardType(.decimalPad)
                }

                Section("Optional micros") {
                    TextField("Fiber (g)", text: $fiberText)
                        .keyboardType(.decimalPad)
                    TextField("Sugar (g)", text: $sugarText)
                        .keyboardType(.decimalPad)
                    TextField("Sodium (mg)", text: $sodiumText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    LabeledContent("Logged via", value: meal.inputMethod.displayLabel)
                    Text("Saving keeps this meal’s id so iCloud sync and Health samples update in place.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(Typography.caption)
                            .foregroundStyle(Color.statusError)
                    }
                }
            }
            .navigationTitle("Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Add a meal title."
            return
        }
        guard let calories = Double(normalized(caloriesText)), calories >= 0 else {
            errorMessage = "Enter valid calories."
            return
        }
        let protein = Double(normalized(proteinText)) ?? 0
        let carbs = Double(normalized(carbsText)) ?? 0
        let fat = Double(normalized(fatText)) ?? 0
        guard protein >= 0, carbs >= 0, fat >= 0 else {
            errorMessage = "Enter valid nutrition numbers."
            return
        }

        var updated = meal
        updated.title = trimmedTitle
        updated.mealType = mealType
        updated.eatenAt = eatenAt
        updated.notes = {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        updated.nutrients = NutrientSet(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: Double(normalized(fiberText)),
            sugar: Double(normalized(sugarText)),
            sodiumMg: Double(normalized(sodiumText))
        )
        updated.updatedAt = .now

        do {
            try await environment.diary.saveMeal(updated)
            environment.analytics.track(.mealSaved)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Could not save meal."
            environment.crashReporter.record(error: error, context: "meal.edit")
        }
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    }

    private static func numberString(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }
}

extension MealInputMethod {
    var displayLabel: String {
        switch self {
        case .quickAdd: "Quick add"
        case .manualSearch: "Food search"
        case .barcode: "Barcode"
        case .photoScan: "Photo scan"
        case .duplicated: "Logged again"
        case .voice: "Voice"
        case .labelScan: "Nutrition label"
        case .recipeURL: "Recipe URL"
        case .recipeBuilder: "Recipe builder"
        }
    }
}

#if !LEGACY_BUILD
#Preview {
    MealDetailEditorView(
        meal: MealRecord(
            mealType: .lunch,
            title: "Chicken bowl",
            nutrients: NutrientSet(calories: 620, protein: 48, carbs: 55, fat: 18),
            inputMethod: .quickAdd
        )
    )
    .environment(\.appEnvironment, .preview)
}
#endif
