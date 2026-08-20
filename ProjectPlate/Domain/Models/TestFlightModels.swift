import Foundation

struct MealCorrectionFeedback: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var createdAt: Date
    var mealTitle: String
    var estimatedCalories: Double
    var correctedCalories: Double?
    var notes: String
    var wasHelpful: Bool?
    var buildNumber: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        mealTitle: String,
        estimatedCalories: Double,
        correctedCalories: Double? = nil,
        notes: String,
        wasHelpful: Bool? = nil,
        buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mealTitle = mealTitle
        self.estimatedCalories = estimatedCalories
        self.correctedCalories = correctedCalories
        self.notes = notes
        self.wasHelpful = wasHelpful
        self.buildNumber = buildNumber
    }
}

protocol CorrectionFeedbackStore: Sendable {
    func save(_ feedback: MealCorrectionFeedback) async throws
    func all() async throws -> [MealCorrectionFeedback]
    func exportJSON() async throws -> Data
    func clear() async throws
}

actor LocalCorrectionFeedbackStore: CorrectionFeedbackStore {
    private let defaults: UserDefaults
    private let key = "plate.testflight.corrections"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ feedback: MealCorrectionFeedback) async throws {
        var items = try await all()
        items.insert(feedback, at: 0)
        let data = try JSONEncoder().encode(items)
        defaults.set(data, forKey: key)
    }

    func all() async throws -> [MealCorrectionFeedback] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([MealCorrectionFeedback].self, from: data)
    }

    func exportJSON() async throws -> Data {
        let items = try await all()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(items)
    }

    func clear() async throws {
        defaults.removeObject(forKey: key)
    }
}

/// Deterministic offline benchmark for vision→nutrition drafts (TestFlight eval support).
struct AIBenchmarkCase: Sendable, Equatable {
    var id: String
    var fixture: MockMealVisionProvider.Fixture
    var expectedMinItems: Int
    var expectedMaxCalorieErrorPercent: Double
    var referenceCalories: Double
}

struct AIBenchmarkResult: Sendable, Equatable {
    var caseID: String
    var passed: Bool
    var itemCount: Int
    var estimatedCalories: Double
    var calorieErrorPercent: Double
    var notes: String
}

enum AIBenchmarkRunner {
    static let defaultCases: [AIBenchmarkCase] = [
        AIBenchmarkCase(
            id: "chicken_bowl",
            fixture: .chickenRiceBowl,
            expectedMinItems: 3,
            expectedMaxCalorieErrorPercent: 25,
            // Approx reference for chicken+rice+avocado+sauce portion set.
            referenceCalories: 620
        ),
        AIBenchmarkCase(
            id: "yogurt_bowl",
            fixture: .yogurtBowl,
            expectedMinItems: 2,
            expectedMaxCalorieErrorPercent: 25,
            referenceCalories: 280
        ),
        AIBenchmarkCase(
            id: "empty_plate",
            fixture: .emptyPlate,
            expectedMinItems: 0,
            expectedMaxCalorieErrorPercent: 100,
            referenceCalories: 0
        ),
    ]

    static func run(
        cases: [AIBenchmarkCase] = defaultCases,
        nutritionRepository: any NutritionRepository = LocalNutritionRepository(openFoodFacts: nil)
    ) async -> [AIBenchmarkResult] {
        var results: [AIBenchmarkResult] = []
        for testCase in cases {
            let service = MealAnalysisService(
                visionProvider: MockMealVisionProvider(fixture: testCase.fixture, delayNanoseconds: 0),
                nutritionRepository: nutritionRepository
            )
            do {
                let draft = try await service.analyze(
                    imageData: Data(repeating: 9, count: 16),
                    context: .default,
                    onStage: { _ in }
                )
                let calories = draft.nutrients.calories
                let errorPercent: Double
                if testCase.referenceCalories <= 0 {
                    errorPercent = calories == 0 ? 0 : 100
                } else {
                    errorPercent = abs(calories - testCase.referenceCalories) / testCase.referenceCalories * 100
                }
                let itemOK = draft.items.count >= testCase.expectedMinItems
                let calorieOK = errorPercent <= testCase.expectedMaxCalorieErrorPercent
                    || testCase.fixture == .emptyPlate
                results.append(
                    AIBenchmarkResult(
                        caseID: testCase.id,
                        passed: itemOK && calorieOK,
                        itemCount: draft.items.count,
                        estimatedCalories: calories,
                        calorieErrorPercent: errorPercent,
                        notes: calorieOK ? "ok" : "calorie error \(Int(errorPercent.rounded()))%"
                    )
                )
            } catch {
                results.append(
                    AIBenchmarkResult(
                        caseID: testCase.id,
                        passed: false,
                        itemCount: 0,
                        estimatedCalories: 0,
                        calorieErrorPercent: 100,
                        notes: error.localizedDescription
                    )
                )
            }
        }
        return results
    }

    static func passRate(_ results: [AIBenchmarkResult]) -> Double {
        guard !results.isEmpty else { return 0 }
        let passed = results.filter(\.passed).count
        return Double(passed) / Double(results.count)
    }
}

/// Remote-config style flag for paywall experiments — off until retention is credible.
struct ExperimentFlags: Sendable {
    var paywallABEnabled: Bool

    static let storageKey = "plate.experiment.paywall_ab"
    static let `default` = ExperimentFlags(paywallABEnabled: false)

    static func load(defaults: UserDefaults = .standard) -> ExperimentFlags {
        ExperimentFlags(paywallABEnabled: defaults.bool(forKey: storageKey))
    }

    static func setPaywallABEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: storageKey)
    }
}
