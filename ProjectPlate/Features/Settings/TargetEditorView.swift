import SwiftUI

/// Settings → Profile → Edit targets (PRODUCT_SPEC §21 / offline target editing).
/// Saves a **new** `NutritionTargetSnapshot` so historical days keep their prior target.
struct TargetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var macroPreference: MacroPreference = .balanced
    @State private var redistributeMacros = true
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var didLoad = false

    var body: some View {
        Form {
            Section {
                Text("Changes apply from today forward. Past days keep the targets they had then.")
                    .font(Typography.supporting)
                    .foregroundStyle(Color.textSecondary)
            }

            Section("Daily calories") {
                TextField("Calories", text: $caloriesText)
                    .keyboardType(.numberPad)
                    .onChangeCompat(of: caloriesText) { _ in
                        if redistributeMacros { applyMacroPreference() }
                    }
            }

            Section("Macros") {
                Picker("Split", selection: $macroPreference) {
                    ForEach(MacroPreference.allCases.filter { $0 != .custom }, id: \.self) { pref in
                        Text(pref.title).tag(pref)
                    }
                }
                .onChangeCompat(of: macroPreference) { _ in
                    if redistributeMacros { applyMacroPreference() }
                }
                Toggle("Recalculate macros from calories", isOn: $redistributeMacros)
                    .onChangeCompat(of: redistributeMacros) { enabled in
                        if enabled { applyMacroPreference() }
                    }
                TextField("Protein (g)", text: $proteinText)
                    .keyboardType(.numberPad)
                    .disabled(redistributeMacros)
                TextField("Carbs (g)", text: $carbsText)
                    .keyboardType(.numberPad)
                    .disabled(redistributeMacros)
                TextField("Fat (g)", text: $fatText)
                    .keyboardType(.numberPad)
                    .disabled(redistributeMacros)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Color.statusError)
                }
            }
            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Section {
                Button(isSaving ? "Saving…" : "Save targets") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }

            Section {
                Text("Nutrition targets are for informational tracking and may be inaccurate. This is not medical advice.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .navigationTitle("Edit targets")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didLoad else { return }
            didLoad = true
            await loadCurrent()
        }
    }

    private func loadCurrent() async {
        if let profile = try? await environment.profileRepository.loadProfile() {
            macroPreference = profile.macroPreference
        }
        if let target = try? await environment.targetRepository.currentTarget(on: .now) {
            caloriesText = "\(target.calories)"
            proteinText = "\(target.proteinGrams)"
            carbsText = "\(target.carbGrams)"
            fatText = "\(target.fatGrams)"
        } else {
            caloriesText = "2000"
            applyMacroPreference()
        }
    }

    private func applyMacroPreference() {
        guard let calories = Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)), calories > 0 else { return }
        let macros = TargetCalculator.macroGrams(calories: calories, preference: macroPreference)
        proteinText = "\(macros.protein)"
        carbsText = "\(macros.carbs)"
        fatText = "\(macros.fat)"
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        guard let calories = Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)),
              calories >= 800, calories <= 6000
        else {
            errorMessage = "Enter a calorie target between 800 and 6000."
            return
        }
        if redistributeMacros {
            applyMacroPreference()
        }
        guard let protein = Int(proteinText.trimmingCharacters(in: .whitespacesAndNewlines)), protein >= 0,
              let carbs = Int(carbsText.trimmingCharacters(in: .whitespacesAndNewlines)), carbs >= 0,
              let fat = Int(fatText.trimmingCharacters(in: .whitespacesAndNewlines)), fat >= 0
        else {
            errorMessage = "Enter whole-number macro grams."
            return
        }

        let roundedCalories = TargetCalculator.roundCalories(Double(calories))
        let snapshot = NutritionTargetSnapshot(
            effectiveDate: Calendar.current.startOfDay(for: .now),
            calories: roundedCalories,
            proteinGrams: protein,
            carbGrams: carbs,
            fatGrams: fat,
            source: .manual
        )
        do {
            if var profile = try await environment.profileRepository.loadProfile() {
                profile.macroPreference = macroPreference
                try await environment.profileRepository.saveProfile(profile)
            }
            try await environment.targetRepository.saveTarget(snapshot)
            statusMessage = "Saved \(roundedCalories) cal · P \(protein)g · C \(carbs)g · F \(fat)g"
            try? await Task.sleep(nanoseconds: 600_000_000)
            dismiss()
        } catch {
            errorMessage = "Could not save targets."
            environment.crashReporter.record(error: error, context: "targets.save")
        }
    }
}

#if !LEGACY_BUILD
#Preview {
    NavigationStack {
        TargetEditorView()
            .environment(\.appEnvironment, .preview)
    }
#endif
}
