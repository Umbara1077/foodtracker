import SwiftUI

struct FoodEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    let food: NutritionFood
    var inputMethod: MealInputMethod
    var onSaved: (() -> Void)?

    @State private var grams: Double
    @State private var mealType: MealType = .inferred()
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        food: NutritionFood,
        inputMethod: MealInputMethod = .manualSearch,
        onSaved: (() -> Void)? = nil
    ) {
        self.food = food
        self.inputMethod = inputMethod
        self.onSaved = onSaved
        _grams = State(initialValue: food.serving?.grams ?? 100)
    }

    private var nutrients: NutrientSet {
        NutritionResolver.nutrients(for: food, grams: grams)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(food.name)
                        .font(Typography.body.weight(.semibold))
                    if let brand = food.brand, !brand.isEmpty {
                        Text(brand)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text(sourceLabel)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Section("Portion") {
                    HStack {
                        Text("Grams")
                        Spacer()
                        Text("\(Int(grams.rounded())) g")
                            .foregroundStyle(Color.textSecondary)
                    }
                    Slider(value: $grams, in: 5...600, step: 5)
                    if let serving = food.serving {
                        Button("Use \(serving.label) (\(Int(serving.grams))g)") {
                            grams = serving.grams
                        }
                    }
                }

                Section("Nutrition") {
                    LabeledContent("Calories", value: "\(Int(nutrients.calories.rounded()))")
                    LabeledContent("Protein", value: "\(nutrients.protein) g")
                    LabeledContent("Carbs", value: "\(nutrients.carbs) g")
                    LabeledContent("Fat", value: "\(nutrients.fat) g")
                }

                Section("Log") {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Note (optional)", text: $note)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(
                inputMethod == .barcode
                    ? "Add barcode item"
                    : inputMethod == .labelScan ? "Add from label" : "Add food"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var sourceLabel: String {
        switch food.source {
        case .usdaShapedFixture: "USDA-shaped catalog"
        case .usdaFoodDataCentral: "USDA FoodData Central"
        case .openFoodFacts: "Open Food Facts"
        case .userCustom: "Custom"
        case .aiEstimate: "AI estimate — review recommended"
        case .nutritionLabelOCR: "Nutrition label OCR — review recommended"
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let meal = MealRecord(
            mealType: mealType,
            title: food.name,
            notes: note.isEmpty ? nil : note,
            nutrients: nutrients,
            inputMethod: inputMethod
        )
        do {
            try await environment.diary.saveMeal(meal)
            environment.analytics.track(.mealSaved)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Could not save food."
            isSaving = false
        }
    }
}
