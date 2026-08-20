import Foundation

enum MealAnalysisStage: Equatable, Sendable {
    case preparingImage
    case identifyingFood
    case resolvingNutrition
    case validating
    case complete
}

struct VisionFoodItem: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var displayName: String
    var canonicalQuery: String
    var estimatedGrams: Double
    var gramRangeLow: Double
    var gramRangeHigh: Double
    var preparation: String?
    var brandOrRestaurant: String?
    var visibleAdditions: [String]
    var confidence: Double

    init(
        id: UUID = UUID(),
        displayName: String,
        canonicalQuery: String,
        estimatedGrams: Double,
        gramRangeLow: Double,
        gramRangeHigh: Double,
        preparation: String? = nil,
        brandOrRestaurant: String? = nil,
        visibleAdditions: [String] = [],
        confidence: Double
    ) {
        self.id = id
        self.displayName = displayName
        self.canonicalQuery = canonicalQuery
        self.estimatedGrams = estimatedGrams
        self.gramRangeLow = gramRangeLow
        self.gramRangeHigh = gramRangeHigh
        self.preparation = preparation
        self.brandOrRestaurant = brandOrRestaurant
        self.visibleAdditions = visibleAdditions
        self.confidence = confidence
    }
}

struct VisionMealDraft: Codable, Sendable, Equatable {
    var schemaVersion: Int
    var mealName: String
    var items: [VisionFoodItem]
    var overallConfidence: Double
    var clarifyingQuestion: String?
    var uncertaintyNotes: [String]

    init(
        schemaVersion: Int = 1,
        mealName: String,
        items: [VisionFoodItem],
        overallConfidence: Double,
        clarifyingQuestion: String? = nil,
        uncertaintyNotes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.mealName = mealName
        self.items = items
        self.overallConfidence = overallConfidence
        self.clarifyingQuestion = clarifyingQuestion
        self.uncertaintyNotes = uncertaintyNotes
    }
}

struct MealAnalysisContext: Sendable {
    var mealHint: MealType?
    var localeIdentifier: String
    var units: UnitSystem

    static let `default` = MealAnalysisContext(
        mealHint: nil,
        localeIdentifier: Locale.current.identifier,
        units: .metric
    )
}

struct ResolvedMealItem: Identifiable, Sendable, Equatable {
    var id: UUID
    var displayName: String
    var grams: Double
    var gramRangeLow: Double
    var gramRangeHigh: Double
    var nutrients: NutrientSet
    var per100g: NutrientSet
    var calorieRangeLow: Double
    var calorieRangeHigh: Double
    var confidence: MealConfidence
    var nutritionSourceLabel: String
    var userEdited: Bool

    var scaledNutrients: NutrientSet { nutrients }
}

struct ReviewableMealDraft: Identifiable, Sendable, Equatable {
    var id: UUID
    var title: String
    var mealType: MealType
    var eatenAt: Date
    var items: [ResolvedMealItem]
    var confidence: MealConfidence
    var source: MealInputMethod
    var originalImageData: Data?

    init(
        id: UUID = UUID(),
        title: String,
        mealType: MealType,
        eatenAt: Date = .now,
        items: [ResolvedMealItem],
        confidence: MealConfidence,
        source: MealInputMethod,
        originalImageData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.mealType = mealType
        self.eatenAt = eatenAt
        self.items = items
        self.confidence = confidence
        self.source = source
        self.originalImageData = originalImageData
    }

    var nutrients: NutrientSet {
        items.reduce(.zero) { $0 + $1.nutrients }
    }

    var calorieRangeLow: Double {
        items.reduce(0) { $0 + $1.calorieRangeLow }
    }

    var calorieRangeHigh: Double {
        items.reduce(0) { $0 + $1.calorieRangeHigh }
    }
}

protocol MealVisionProvider: Sendable {
    var id: String { get }
    func analyze(imageData: Data, context: MealAnalysisContext) async throws -> VisionMealDraft
}

protocol MealAnalysisServing: Sendable {
    func analyze(
        imageData: Data,
        context: MealAnalysisContext,
        onStage: @Sendable @escaping (MealAnalysisStage) -> Void
    ) async throws -> ReviewableMealDraft
}

enum MealScanError: Error, LocalizedError, Sendable, Equatable {
    case permissionDenied
    case invalidImage
    case providerUnavailable
    case invalidStructuredResponse
    case cancelled
    case network
    case unauthorized
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera access is off."
        case .invalidImage: "That image couldn’t be used."
        case .providerUnavailable: "Meal analysis isn’t available right now."
        case .invalidStructuredResponse: "The scan result was incomplete."
        case .cancelled: "Scan cancelled."
        case .network: "Check your connection and try again."
        case .unauthorized: "Cloud scan isn’t authorized for this build."
        case .quotaExceeded: "You’ve used today’s free cloud scans. Try again tomorrow, or log with Search / Quick add."
        }
    }
}
