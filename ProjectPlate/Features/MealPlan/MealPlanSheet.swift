import SwiftUI

struct MealPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    var initialDay: Date = .now
    var onSaved: (() -> Void)?

    @State private var day: Date
    @State private var mealType: MealType = .inferred()
    @State private var title = ""
    @State private var favorites: [SavedMealTemplate] = []
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(initialDay: Date = .now, onSaved: (() -> Void)? = nil) {
        self.initialDay = initialDay
        self.onSaved = onSaved
        _day = State(initialValue: Calendar.current.startOfDay(for: initialDay))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }
                Section("What") {
                    TextField("Meal title", text: $title)
                        .textInputAutocapitalization(.sentences)
                    if !favorites.isEmpty {
                        ForEach(favorites) { favorite in
                            Button {
                                title = favorite.title
                                mealType = favorite.mealType
                            } label: {
                                HStack {
                                    Text(favorite.title)
                                    Spacer()
                                    Text("Favorite")
                                        .font(Typography.caption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Plan a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task {
                favorites = (try? await environment.savedMeals.frequent(limit: 8)) ?? []
            }
        }
    }

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Add a short meal title."
            return
        }
        isSaving = true
        errorMessage = nil
        let matched = favorites.first {
            $0.title.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        let plan = PlannedMeal(
            dayStart: Calendar.current.startOfDay(for: day),
            mealType: mealType,
            title: trimmed,
            savedMealFingerprint: matched?.fingerprint
        )
        do {
            try await environment.mealPlan.upsert(plan)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = "Could not save plan."
            isSaving = false
        }
    }
}

#Preview {
    MealPlanSheet()
        .environment(\.appEnvironment, .preview)
}
