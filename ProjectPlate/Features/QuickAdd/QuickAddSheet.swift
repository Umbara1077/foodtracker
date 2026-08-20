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
    @State private var voiceCapturer = SpeechVoiceMealCapturer()
    @State private var isListening = false
    @State private var usedVoice = false
    @State private var liveTranscript = ""

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
                Section("Voice") {
                    if isListening {
                        Text(liveTranscript.isEmpty ? "Listening…" : liveTranscript)
                            .font(Typography.supporting)
                            .foregroundStyle(Color.textSecondary)
                        Button("Stop & fill fields", role: .destructive) {
                            stopVoice()
                        }
                    } else {
                        Button {
                            Task { await startVoice() }
                        } label: {
                            Label("Speak meal", systemImage: "mic.fill")
                        }
                        .disabled(!voiceCapturer.isAvailable)
                        Text("Try “Greek yogurt 180 calories 20 protein”.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
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
                    Button("Cancel") {
                        _ = voiceCapturer.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || isListening)
                }
            }
            .onChange(of: calories) { _, _ in refreshWarning() }
            .onChange(of: protein) { _, _ in refreshWarning() }
            .onChange(of: carbs) { _, _ in refreshWarning() }
            .onChange(of: fat) { _, _ in refreshWarning() }
            .onDisappear {
                _ = voiceCapturer.stop()
            }
        }
    }

    private func startVoice() async {
        errorMessage = nil
        let authorized = await voiceCapturer.requestAuthorization()
        guard authorized else {
            errorMessage = VoiceCaptureError.notAuthorized.localizedDescription
            return
        }
        do {
            try voiceCapturer.start { partial in
                liveTranscript = partial
            }
            isListening = true
            liveTranscript = ""
        } catch {
            errorMessage = error.localizedDescription
            isListening = false
        }
    }

    private func stopVoice() {
        let transcript = voiceCapturer.stop()
        isListening = false
        applyVoiceTranscript(transcript.isEmpty ? liveTranscript : transcript)
    }

    private func applyVoiceTranscript(_ transcript: String) {
        let draft = VoiceMealParser.parse(transcript)
        if let spokenTitle = draft.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = spokenTitle
        }
        if let value = draft.calories { calories = formatNumber(value) }
        if let value = draft.protein { protein = formatNumber(value) }
        if let value = draft.carbs { carbs = formatNumber(value) }
        if let value = draft.fat { fat = formatNumber(value) }
        if notes.isEmpty {
            notes = transcript
        }
        usedVoice = true
        refreshWarning()
    }

    private func formatNumber(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
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
            inputMethod: usedVoice ? .voice : .quickAdd
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
