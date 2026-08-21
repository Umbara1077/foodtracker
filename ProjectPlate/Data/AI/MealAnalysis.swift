import Foundation

/// Deterministic fixture provider for Phase 3/4 — no network / no API keys.
struct MockMealVisionProvider: MealVisionProvider {
    let id = "mock-fixture"

    enum Fixture: String, Sendable {
        case chickenRiceBowl
        case yogurtBowl
        case chipotleBowl
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
                        canonicalQuery: "avocado",
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
                        canonicalQuery: "greek yogurt",
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
        case .chipotleBowl:
            return VisionMealDraft(
                mealName: "Chipotle burrito bowl",
                items: [
                    VisionFoodItem(
                        displayName: "Chicken",
                        canonicalQuery: "chicken",
                        estimatedGrams: 113,
                        gramRangeLow: 90,
                        gramRangeHigh: 130,
                        preparation: "grilled",
                        brandOrRestaurant: "Chipotle",
                        confidence: 0.88
                    ),
                    VisionFoodItem(
                        displayName: "Cilantro-lime rice",
                        canonicalQuery: "cilantro lime rice",
                        estimatedGrams: 113,
                        gramRangeLow: 90,
                        gramRangeHigh: 140,
                        brandOrRestaurant: "Chipotle",
                        confidence: 0.84
                    ),
                    VisionFoodItem(
                        displayName: "Black beans",
                        canonicalQuery: "black beans",
                        estimatedGrams: 113,
                        gramRangeLow: 90,
                        gramRangeHigh: 130,
                        brandOrRestaurant: "Chipotle",
                        confidence: 0.86
                    ),
                    VisionFoodItem(
                        displayName: "Guacamole",
                        canonicalQuery: "guacamole",
                        estimatedGrams: 80,
                        gramRangeLow: 50,
                        gramRangeHigh: 110,
                        brandOrRestaurant: "Chipotle",
                        confidence: 0.8
                    ),
                ],
                overallConfidence: 0.85,
                uncertaintyNotes: ["Restaurant portions vary — review recommended."]
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

/// Small fallback table when catalog search misses.
enum FixtureNutritionDatabase {
    struct Entry {
        let name: String
        let per100g: NutrientSet
        let sourceLabel: String
    }

    static let entries: [String: Entry] = [
        "savory sauce": Entry(
            name: "Savory sauce",
            per100g: NutrientSet(calories: 120, protein: 1, carbs: 8, fat: 9),
            sourceLabel: "Fixture estimate"
        ),
    ]

    static func lookup(_ query: String) -> Entry {
        let key = query.lowercased()
        if let hit = entries[key] { return hit }
        if let hit = entries.first(where: { key.contains($0.key) || $0.key.contains(key) })?.value {
            return hit
        }
        return Entry(
            name: query,
            per100g: NutrientSet(calories: 150, protein: 8, carbs: 15, fat: 6),
            sourceLabel: "Fixture fallback"
        )
    }

    static func scale(_ per100g: NutrientSet, grams: Double) -> NutrientSet {
        NutritionResolver.nutrients(
            for: NutritionFood(
                id: "tmp",
                source: .aiEstimate,
                name: "tmp",
                brand: nil,
                serving: nil,
                per100g: per100g
            ),
            grams: grams
        )
    }
}

struct MealAnalysisService: MealAnalysisServing {
    let visionProvider: any MealVisionProvider
    let nutritionRepository: any NutritionRepository

    init(
        visionProvider: any MealVisionProvider,
        nutritionRepository: any NutritionRepository
    ) {
        self.visionProvider = visionProvider
        self.nutritionRepository = nutritionRepository
    }

    func analyze(
        imageData: Data,
        context: MealAnalysisContext,
        onStage: @Sendable @escaping (MealAnalysisStage) -> Void
    ) async throws -> ReviewableMealDraft {
        onStage(.preparingImage)
        let normalized = ImagePreprocessor.normalizeForUpload(imageData)
        guard !normalized.isEmpty else { throw MealScanError.invalidImage }

        onStage(.identifyingFood)
        let rawDraft = try await visionProvider.analyze(imageData: normalized, context: context)
        let draft = try VisionDraftValidator.validate(rawDraft)

        onStage(.resolvingNutrition)
        var items: [ResolvedMealItem] = []
        for visionItem in draft.items {
            let food = try await resolveFood(for: visionItem, locale: Locale(identifier: context.localeIdentifier))
            let nutrients = NutritionResolver.nutrients(for: food, grams: visionItem.estimatedGrams)
            let low = NutritionResolver.nutrients(for: food, grams: visionItem.gramRangeLow)
            let high = NutritionResolver.nutrients(for: food, grams: visionItem.gramRangeHigh)
            items.append(
                ResolvedMealItem(
                    id: visionItem.id,
                    displayName: food.name,
                    grams: visionItem.estimatedGrams,
                    gramRangeLow: visionItem.gramRangeLow,
                    gramRangeHigh: visionItem.gramRangeHigh,
                    nutrients: nutrients,
                    per100g: food.per100g,
                    calorieRangeLow: low.calories,
                    calorieRangeHigh: high.calories,
                    confidence: MealConfidence.from(score: visionItem.confidence),
                    nutritionSourceLabel: sourceLabel(food.source),
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

    private func resolveFood(for item: VisionFoodItem, locale: Locale) async throws -> NutritionFood {
        let query = RestaurantMealMatcher.searchQuery(for: item, locale: locale)
        let candidates = try await nutritionRepository.search(query)
        if let best = RestaurantMealMatcher.preferredCandidate(
            from: candidates,
            brandOrRestaurant: item.brandOrRestaurant
        ), best.score >= 0.12 {
            return best.food
        }

        let entry = FixtureNutritionDatabase.lookup(item.canonicalQuery)
        return NutritionFood(
            id: "fixture.\(item.canonicalQuery)",
            source: .aiEstimate,
            name: item.displayName,
            brand: item.brandOrRestaurant,
            serving: ServingDescriptor(label: "portion", grams: item.estimatedGrams),
            per100g: entry.per100g
        )
    }

    private func sourceLabel(_ source: NutritionSource) -> String {
        switch source {
        case .usdaShapedFixture: "Catalog · USDA-shaped"
        case .usdaFoodDataCentral: "USDA FoodData Central"
        case .openFoodFacts: "Open Food Facts"
        case .userCustom: "Custom"
        case .aiEstimate: "AI estimate — review recommended"
        case .nutritionLabelOCR: "Nutrition label OCR — review recommended"
        case .restaurantCatalog: "Restaurant catalog — review recommended"
        }
    }
}

enum ImagePreprocessor {
    /// Re-encodes to JPEG (strips EXIF/GPS). Never truncates raw bytes mid-container.
    static func normalizeForUpload(_ data: Data, maxBytes: Int = 2_500_000) -> Data {
        MealImageEncoder.privacySafeJPEG(from: data, maxBytes: maxBytes) ?? Data()
    }
}
