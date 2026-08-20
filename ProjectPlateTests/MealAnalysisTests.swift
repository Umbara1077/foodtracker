import Testing
@testable import ProjectPlate
import Foundation

struct MealAnalysisTests {
    @Test("Mock vision + fixture nutrition produces a reviewable draft")
    func chickenBowlAnalysis() async throws {
        let service = MealAnalysisService(
            visionProvider: MockMealVisionProvider(fixture: .chickenRiceBowl, delayNanoseconds: 0)
        )
        var stages: [MealAnalysisStage] = []
        let draft = try await service.analyze(
            imageData: Data(repeating: 1, count: 16),
            context: .default,
            onStage: { stages.append($0) }
        )
        #expect(draft.title == "Chicken rice bowl")
        #expect(draft.items.count == 4)
        #expect(draft.nutrients.calories > 0)
        #expect(draft.calorieRangeHigh >= draft.calorieRangeLow)
        #expect(stages.contains(.identifyingFood))
        #expect(stages.contains(.complete))
        #expect(draft.source == .photoScan)
    }

    @Test("Empty image data fails")
    func emptyImage() async throws {
        let service = MealAnalysisService(
            visionProvider: MockMealVisionProvider(delayNanoseconds: 0)
        )
        do {
            _ = try await service.analyze(
                imageData: Data(),
                context: .default,
                onStage: { _ in }
            )
            Issue.record("Expected invalidImage error")
        } catch let error as MealScanError {
            #expect(error == .invalidImage)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test("Empty plate fixture yields no items")
    func emptyPlate() async throws {
        let service = MealAnalysisService(
            visionProvider: MockMealVisionProvider(fixture: .emptyPlate, delayNanoseconds: 0)
        )
        let draft = try await service.analyze(
            imageData: Data(repeating: 2, count: 8),
            context: .default,
            onStage: { _ in }
        )
        #expect(draft.items.isEmpty)
        #expect(draft.confidence == .low)
    }

    @Test("Portion rescale is deterministic from per-100g")
    func rescale() {
        let per100 = NutrientSet(calories: 165, protein: 31, carbs: 0, fat: 3.6)
        let scaled = FixtureNutritionDatabase.scale(per100, grams: 135)
        #expect(scaled.calories == (165 * 1.35).rounded())
    }
}
