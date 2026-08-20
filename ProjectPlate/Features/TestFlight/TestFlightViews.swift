import SwiftUI
import UniformTypeIdentifiers

struct CorrectionFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    var mealTitle: String
    var estimatedCalories: Double

    @State private var notes = ""
    @State private var correctedCaloriesText = ""
    @State private var wasHelpful: Bool?
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Text(mealTitle)
                    Text("Estimate \(Int(estimatedCalories.rounded())) cal")
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Your correction") {
                    TextField("Corrected calories (optional)", text: $correctedCaloriesText)
                        .keyboardType(.decimalPad)
                    TextField("What should we improve?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Was the estimate helpful?", selection: $wasHelpful) {
                        Text("Not sure").tag(Optional<Bool>.none)
                        Text("Yes").tag(Optional.some(true))
                        Text("No").tag(Optional.some(false))
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Send correction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let corrected = Double(correctedCaloriesText.replacingOccurrences(of: ",", with: "."))
        let feedback = MealCorrectionFeedback(
            mealTitle: mealTitle,
            estimatedCalories: estimatedCalories,
            correctedCalories: corrected,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            wasHelpful: wasHelpful
        )
        do {
            try await environment.correctionStore.save(feedback)
            let brands = RestaurantBrandHistory.brands(from: try await environment.correctionStore.all())
            await environment.nutritionRepository.setPreferredBrandHistory(brands)
            dismiss()
        } catch {
            errorMessage = "Could not save feedback."
            isSaving = false
            environment.crashReporter.record(error: error, context: "feedback.save")
        }
    }
}

struct TestFlightToolsView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var feedbackCount = 0
    @State private var exportDocument: CorrectionsExportDocument?
    @State private var benchmarkSummary: String?
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        List {
            Section("Corrections") {
                LabeledContent("Stored locally", value: "\(feedbackCount)")
                Button("Export corrections JSON") {
                    Task { await exportCorrections() }
                }
                .disabled(isWorking || feedbackCount == 0)
                Button("Clear corrections", role: .destructive) {
                    Task { await clearCorrections() }
                }
                .disabled(isWorking || feedbackCount == 0)
            }
            Section("AI benchmark") {
                Text("Runs deterministic fixture meals offline. Use this before changing vision models.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                Button("Run fixture benchmark") {
                    Task { await runBenchmark() }
                }
                .disabled(isWorking)
                if let benchmarkSummary {
                    Text(benchmarkSummary)
                        .font(Typography.supporting)
                }
            }
            Section("Experiments") {
                Toggle(
                    "Paywall A/B (off until retention is credible)",
                    isOn: Binding(
                        get: { ExperimentFlags.load().paywallABEnabled },
                        set: { ExperimentFlags.setPaywallABEnabled($0) }
                    )
                )
                Text("Keep this off for early TestFlight. Enable only after D7 retention looks real.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            if let message {
                Section {
                    Text(message).font(Typography.caption)
                }
            }
        }
        .navigationTitle("TestFlight tools")
        .task { await refresh() }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: .json,
            defaultFilename: "project-plate-corrections"
        ) { result in
            if case .success = result {
                message = "Corrections exported."
            }
        }
    }

    private func refresh() async {
        feedbackCount = (try? await environment.correctionStore.all().count) ?? 0
    }

    private func exportCorrections() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let data = try await environment.correctionStore.exportJSON()
            exportDocument = CorrectionsExportDocument(data: data)
        } catch {
            message = "Export failed."
        }
    }

    private func clearCorrections() async {
        isWorking = true
        defer { isWorking = false }
        try? await environment.correctionStore.clear()
        await refresh()
        message = "Corrections cleared."
    }

    private func runBenchmark() async {
        isWorking = true
        defer { isWorking = false }
        let results = await AIBenchmarkRunner.run()
        let rate = Int((AIBenchmarkRunner.passRate(results) * 100).rounded())
        let failed = results.filter { !$0.passed }.map(\.caseID).joined(separator: ", ")
        benchmarkSummary = failed.isEmpty
            ? "Pass rate \(rate)% — all cases passed."
            : "Pass rate \(rate)%. Failed: \(failed)"
    }
}

struct CorrectionsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
