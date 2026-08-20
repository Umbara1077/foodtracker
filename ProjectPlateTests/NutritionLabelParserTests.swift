import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 18 — Nutrition label OCR parsing")
struct NutritionLabelParserTests {
    @Test("Parses a typical Nutrition Facts block")
    func typicalLabel() {
        let text = """
        Acme Granola
        Nutrition Facts
        Serving Size 55 g
        Calories 250
        Total Fat 9 g
        Total Carbohydrate 36 g
        Protein 6 g
        """
        let draft = NutritionLabelParser.parse(text: text)
        #expect(draft.servingGrams == 55)
        #expect(draft.caloriesPerServing == 250)
        #expect(draft.fatPerServing == 9)
        #expect(draft.carbsPerServing == 36)
        #expect(draft.proteinPerServing == 6)
        #expect(draft.productName?.lowercased().contains("granola") == true)
        #expect(draft.isUsable)

        let food = draft.asNutritionFood(id: "test")
        #expect(food?.source == .nutritionLabelOCR)
        // 250 cal / 55 g → per 100g ≈ 454.5
        #expect(abs((food?.per100g.calories ?? 0) - (250 * 100 / 55)) < 0.01)
        #expect(food?.serving?.grams == 55)
    }

    @Test("Unusable when no macros found")
    func empty() {
        let draft = NutritionLabelParser.parse(text: "Hello world")
        #expect(!draft.isUsable)
        #expect(draft.asNutritionFood() == nil)
    }
}
