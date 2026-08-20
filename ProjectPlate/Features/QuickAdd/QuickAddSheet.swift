import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var title = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var notes = ""
    @State private var mealType: MealType = .inferred()
    @State private var warning: String?
    @State private var errorMessage: String?
    @State private var isSaving = false

    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name (optional)", text: $title)
                    Picker("Type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }
                Section("Nutrition") {
                    TextField("Calories", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                    if let warning {
                        Text(warning)
                            .font(Typography.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Section("Notes") {
                    TextField("Optional note", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(Typography.caption)
                    }
                }
            }
            .navigationTitle("Quick add")
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
            .onChange(of: calories) { _, _ in refreshWarning() }
            .onChange(of: protein) { _, _ in refreshWarning() }
            .onChange(of: carbs) { _, _ in refreshWarning() }
            .onChange(of: fat) { _, _ in refreshWarning() }
        }
    }

    private func refreshWarning() {
        let resolved = QuickAddMath.resolve(
            caloriesText: calories,
            protein: Double(protein),
            carbs: Double(carbs),
            fat: Double(fat)
        )
        warning = resolved.warning
    }

    private func save() async {
        errorMessage = nil
        let resolved = QuickAddMath.resolve(
            caloriesText: calories,
            protein: Double(protein),
            carbs: Double(carbs),
            fat: Double(fat)
        )
        warning = resolved.warning
        guard resolved.calories > 0 else {
            errorMessage = resolved.warning ?? "Enter calories or macros."
            return
        }

        isSaving = true
        let meal = MealRecord(
            mealType: mealType,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Quick add"
                : title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes,
            nutrients: NutrientSet(
                calories: resolved.calories,
                protein: Double(protein) ?? 0,
                carbs: Double(carbs) ?? 0,
                fat: Double(fat) ?? 0
            ),
            inputMethod: .quickAdd
        )

        do {
            try await environment.diary.saveMeal(meal)
            environment.analytics.track(.mealSaved)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Could not save meal."
            isSaving = false
        }
    }
}

#Preview {
    QuickAddSheet()
        .environment(\.appEnvironment, .preview)
}
