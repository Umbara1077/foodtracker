import Foundation

/// Deterministic fixture provider for Phase 3 — no network / no API keys.
struct MockMealVisionProvider: MealVisionProvider {
    let id = "mock-fixture"

    enum Fixture: String, Sendable {
        case chickenRiceBowl
        case yogurtBowl
        case emptyPlate
    }

    var fixture: Fixture
    var delayNanoseconds: UInt64

    init(fixture: Fixture = .chickenRiceBowl, delayNanoseconds: UInt64 = 600_000_000) {
        self.fixture = fixture
        self.delayNanoseconds = delayNanoseconds
    }

    func analyze(imageData: Data, context: MealAnalysisContext) async throws -> VisionMealDraft {
        guard !imageData.isEmpty else { throw MealScanError.invalidImage }
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        try Task.checkCancellation()

        switch fixture {
        case .chickenRiceBowl:
            return VisionMealDraft(
                mealName: "Chicken rice bowl",
                items: [
                    VisionFoodItem(
                        displayName: "Grilled chicken",
                        canonicalQuery: "chicken breast grilled",
                        estimatedGrams: 135,
                        gramRangeLow: 110,
                        gramRangeHigh: 160,
                        preparation: "grilled",
                        confidence: 0.9
                    ),
                    VisionFoodItem(
                        displayName: "White rice",
                        canonicalQuery: "white rice cooked",
                        estimatedGrams: 180,
                        gramRangeLow: 150,
                        gramRangeHigh: 210,
                        preparation: "cooked",
                        confidence: 0.86
                    ),
                    VisionFoodItem(
                        displayName: "Avocado",
                        canonicalQuery: "avocado raw",
                        estimatedGrams: 55,
                        gramRangeLow: 40,
                        gramRangeHigh: 70,
                        confidence: 0.78
                    ),
                    VisionFoodItem(
                        displayName: "Sauce",
                        canonicalQuery: "savory sauce",
                        estimatedGrams: 28,
                        gramRangeLow: 15,
                        gramRangeHigh: 40,
                        confidence: 0.62
                    ),
                ],
                overallConfidence: 0.82,
                uncertaintyNotes: ["Sauce amount is approximate."]
            )
        case .yogurtBowl:
            return VisionMealDraft(
                mealName: "Yogurt bowl",
                items: [
                    VisionFoodItem(
                        displayName: "Greek yogurt",
                        canonicalQuery: "greek yogurt plain",
                        estimatedGrams: 170,
                        gramRangeLow: 150,
                        gramRangeHigh: 190,
                        confidence: 0.88
                    ),
                    VisionFoodItem(
                        displayName: "Granola",
                        canonicalQuery: "granola",
                        estimatedGrams: 30,
                        gramRangeLow: 20,
                        gramRangeHigh: 40,
                        confidence: 0.74
                    ),
                    VisionFoodItem(
                        displayName: "Blueberries",
                        canonicalQuery: "blueberries",
                        estimatedGrams: 40,
                        gramRangeLow: 30,
                        gramRangeHigh: 55,
                        confidence: 0.8
                    ),
                ],
                overallConfidence: 0.8
            )
        case .emptyPlate:
            return VisionMealDraft(
                mealName: "Unclear meal",
                items: [],
                overallConfidence: 0.2,
                clarifyingQuestion: "I couldn’t confidently find food in this photo.",
                uncertaintyNotes: ["Retake with the whole plate visible."]
            )
        }
    }
}

/// Phase 3 nutrition resolver: maps canonical queries to per-100g fixtures (USDA-shaped, local only).
enum FixtureNutritionDatabase {
    struct Entry {
        let name: String
        let per100g: NutrientSet
        let sourceLabel: String
    }

    static let entries: [String: Entry] = [
        "chicken breast grilled": Entry(
            name: "Grilled chicken breast",
            per100g: NutrientSet(calories: 165, protein: 31, carbs: 0, fat: 3.6),
            sourceLabel: "Fixture · USDA-shaped"
        ),
        "white rice cooked": Entry(
            name: "Cooked white rice",
            per100g: NutrientSet(calories: 130, protein: 2.7, carbs: 28, fat: 0.3),
            sourceLabel: "Fixture · USDA-shaped"
        ),
        "avocado raw": Entry(
            name: "Avocado",
            per100g: NutrientSet(calories: 160, protein: 2, carbs: 8.5, fat: 14.7),
            sourceLabel: "Fixture · USDA-shaped"
        ),
        "savory sauce": Entry(
            name: "Savory sauce",
            per100g: NutrientSet(calories: 120, protein: 1, carbs: 8, fat: 9),
            sourceLabel: "Fixture estimate"
        ),
        "greek yogurt plain": Entry(
            name: "Greek yogurt",
            per100g: NutrientSet(calories: 97, protein: 9, carbs: 3.6, fat: 5),
            sourceLabel: "Fixture · USDA-shaped"
        ),
        "granola": Entry(
            name: "Granola",
            per100g: NutrientSet(calories: 471, protein: 10, carbs: 64, fat: 20),
            sourceLabel: "Fixture · USDA-shaped"
        ),
        "blueberries": Entry(
            name: "Blueberries",
            per100g: NutrientSet(calories: 57, protein: 0.7, carbs: 14.5, fat: 0.3),
            sourceLabel: "Fixture · USDA-shaped"
        ),
    ]

    static func lookup(_ query: String) -> Entry {
        if let hit = entries[query.lowercased()] { return hit }
        return Entry(
            name: query,
            per100g: NutrientSet(calories: 150, protein: 8, carbs: 15, fat: 6),
            sourceLabel: "Fixture fallback"
        )
    }

    static func scale(_ per100g: NutrientSet, grams: Double) -> NutrientSet {
        let factor = grams / 100.0
        return NutrientSet(
            calories: (per100g.calories * factor).rounded(),
            protein: (per100g.protein * factor * 10).rounded() / 10,
            carbs: (per100g.carbs * factor * 10).rounded() / 10,
            fat: (per100g.fat * factor * 10).rounded() / 10
        )
    }
}

struct MealAnalysisService: MealAnalysisServing {
    let visionProvider: any MealVisionProvider

    func analyze(
        imageData: Data,
        context: MealAnalysisContext,
        onStage: @Sendable @escaping (MealAnalysisStage) -> Void
    ) async throws -> ReviewableMealDraft {
        onStage(.preparingImage)
        let normalized = ImagePreprocessor.normalizeForUpload(imageData)
        guard !normalized.isEmpty else { throw MealScanError.invalidImage }

        onStage(.identifyingFood)
        let draft = try await visionProvider.analyze(imageData: normalized, context: context)
        guard draft.schemaVersion == 1 else { throw MealScanError.invalidStructuredResponse }

        onStage(.resolvingNutrition)
        var items: [ResolvedMealItem] = []
        for visionItem in draft.items {
            let entry = FixtureNutritionDatabase.lookup(visionItem.canonicalQuery)
            let nutrients = FixtureNutritionDatabase.scale(entry.per100g, grams: visionItem.estimatedGrams)
            let low = FixtureNutritionDatabase.scale(entry.per100g, grams: visionItem.gramRangeLow)
            let high = FixtureNutritionDatabase.scale(entry.per100g, grams: visionItem.gramRangeHigh)
            items.append(
                ResolvedMealItem(
                    id: visionItem.id,
                    displayName: visionItem.displayName,
                    grams: visionItem.estimatedGrams,
                    gramRangeLow: visionItem.gramRangeLow,
                    gramRangeHigh: visionItem.gramRangeHigh,
                    nutrients: nutrients,
                    per100g: entry.per100g,
                    calorieRangeLow: low.calories,
                    calorieRangeHigh: high.calories,
                    confidence: MealConfidence.from(score: visionItem.confidence),
                    nutritionSourceLabel: entry.sourceLabel,
                    userEdited: false
                )
            )
        }

        onStage(.validating)
        let confidence = MealConfidence.from(score: draft.overallConfidence)
        onStage(.complete)

        return ReviewableMealDraft(
            title: draft.mealName,
            mealType: context.mealHint ?? .inferred(),
            items: items,
            confidence: confidence,
            source: .photoScan,
            originalImageData: normalized
        )
    }
}

enum ImagePreprocessor {
    /// Phase 3: basic size cap without UIKit dependency in unit tests.
    /// Real JPEG resize happens in the UI layer before calling analysis.
    static func normalizeForUpload(_ data: Data, maxBytes: Int = 2_500_000) -> Data {
        if data.count <= maxBytes { return data }
        // Keep a prefix only as a last resort for oversized mock payloads in tests.
        return data.prefix(maxBytes)
    }
}
