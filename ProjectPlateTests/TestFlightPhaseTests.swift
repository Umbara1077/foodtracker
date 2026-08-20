import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 11 — TestFlight support")
struct TestFlightPhaseTests {
    @Test("Correction feedback persists and exports JSON")
    func correctionStore() async throws {
        let defaults = UserDefaults(suiteName: "test.plate.corrections.\(UUID().uuidString)")!
        let store = LocalCorrectionFeedbackStore(defaults: defaults)
        #expect(try await store.all().isEmpty)

        try await store.save(
            MealCorrectionFeedback(
                mealTitle: "Oatmeal",
                estimatedCalories: 300,
                correctedCalories: 250,
                notes: "Too high",
                wasHelpful: false,
                buildNumber: "10"
            )
        )
        let items = try await store.all()
        #expect(items.count == 1)
        #expect(items.first?.notes == "Too high")

        let data = try await store.exportJSON()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([MealCorrectionFeedback].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].correctedCalories == 250)

        try await store.clear()
        #expect(try await store.all().isEmpty)
    }

    @Test("AI benchmark runner scores fixture analysis")
    func benchmarkRunner() async {
        let results = await AIBenchmarkRunner.run()
        #expect(results.count == 3)
        #expect(AIBenchmarkRunner.passRate(results) == 1.0)
        #expect(results.allSatisfy(\.passed))
    }

    @Test("Paywall A/B experiment stays off by default")
    func experimentFlags() {
        let defaults = UserDefaults(suiteName: "test.plate.experiments.\(UUID().uuidString)")!
        #expect(ExperimentFlags.load(defaults: defaults).paywallABEnabled == false)
        ExperimentFlags.setPaywallABEnabled(true, defaults: defaults)
        #expect(ExperimentFlags.load(defaults: defaults).paywallABEnabled == true)
    }
}
