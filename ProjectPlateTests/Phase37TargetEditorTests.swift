import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 37 — Target editor")
struct Phase37TargetEditorTests {
    @Test("Manual target snapshot preserves history by using a new effective day")
    func savesNewSnapshot() async throws {
        let day1 = Date(timeIntervalSince1970: 1_720_000_000)
        let day2 = Date(timeIntervalSince1970: 1_720_086_400)
        let original = NutritionTargetSnapshot(
            effectiveDate: day1,
            calories: 2000,
            proteinGrams: 150,
            carbGrams: 200,
            fatGrams: 60,
            source: .onboardingEstimate
        )
        let repo = InMemoryTargetRepository(targets: [original])
        let updated = NutritionTargetSnapshot(
            effectiveDate: Calendar.current.startOfDay(for: day2),
            calories: 2200,
            proteinGrams: 160,
            carbGrams: 210,
            fatGrams: 65,
            source: .manual
        )
        try await repo.saveTarget(updated)
        let all = try await repo.allTargets()
        #expect(all.count == 2)
        let current = try await repo.currentTarget(on: day2)
        #expect(current?.calories == 2200)
        #expect(current?.source == .manual)
        let past = try await repo.currentTarget(on: day1)
        #expect(past?.calories == 2000)
    }

    @Test("Macro grams redistribute from calorie preference")
    func macroRedistribute() {
        let macros = TargetCalculator.macroGrams(calories: 2000, preference: .higherProtein)
        #expect(macros.protein == 150) // 2000 * 0.30 / 4
        #expect(macros.carbs == 200) // 2000 * 0.40 / 4
        #expect(macros.fat == 67) // 2000 * 0.30 / 9 rounded
        #expect(TargetCalculator.roundCalories(2184) == 2180)
    }
}
