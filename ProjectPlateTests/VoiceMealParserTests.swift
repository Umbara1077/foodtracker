import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 17 — Voice meal parsing")
struct VoiceMealParserTests {
    @Test("Parses calories and protein from a spoken phrase")
    func caloriesAndProtein() {
        let draft = VoiceMealParser.parse("Greek yogurt 180 calories 20 protein")
        #expect(draft.calories == 180)
        #expect(draft.protein == 20)
        #expect(draft.title?.lowercased().contains("greek") == true)
    }

    @Test("Parses full macros with units")
    func fullMacros() {
        let draft = VoiceMealParser.parse("chicken rice bowl 620 cal protein 48g carbs 55 fat 18")
        #expect(draft.calories == 620)
        #expect(draft.protein == 48)
        #expect(draft.carbs == 55)
        #expect(draft.fat == 18)
        #expect(draft.title?.lowercased().contains("chicken") == true)
    }

    @Test("Bare trailing number becomes calories")
    func bareNumber() {
        let draft = VoiceMealParser.parse("oatmeal 350")
        #expect(draft.calories == 350)
        #expect(draft.title?.lowercased().contains("oatmeal") == true)
    }

    @Test("Empty transcript yields empty draft")
    func empty() {
        let draft = VoiceMealParser.parse("   ")
        #expect(draft == VoiceMealParser.Draft())
    }
}
