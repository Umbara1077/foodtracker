import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 15 — Home Screen widget snapshot")
struct WidgetSnapshotTests {
    @Test("Factory maps remaining calories and macros")
    func factory() {
        let target = NutritionTargetSnapshot(
            calories: 2000,
            proteinGrams: 150,
            carbGrams: 200,
            fatGrams: 60,
            source: .manual
        )
        let totals = DayNutritionTotals(
            nutrients: NutrientSet(calories: 650, protein: 40, carbs: 50, fat: 20),
            mealCount: 2
        )
        let snapshot = WidgetSnapshotStore.make(target: target, totals: totals)
        #expect(snapshot.remainingCalories == 1350)
        #expect(snapshot.eatenCalories == 650)
        #expect(snapshot.proteinGrams == 40)
        #expect(snapshot.proteinTargetGrams == 150)
        #expect(snapshot.mealCount == 2)
        #expect(snapshot.headline == "Remaining")
    }

    @Test("Over-target headline flips")
    func overTarget() {
        let snapshot = TodayWidgetSnapshot(
            updatedAt: .now,
            remainingCalories: -120,
            eatenCalories: 2120,
            targetCalories: 2000,
            proteinGrams: 160,
            proteinTargetGrams: 150,
            mealCount: 4
        )
        #expect(snapshot.isOverTarget)
        #expect(snapshot.headline == "Over target")
        #expect(snapshot.remainingDisplay == "120")
    }

    @Test("Snapshot round-trips through UserDefaults suite")
    func persistence() {
        let defaults = UserDefaults(suiteName: "test.plate.widget.\(UUID().uuidString)")!
        let original = TodayWidgetSnapshot.placeholder
        WidgetSnapshotStore.save(original, defaults: defaults)
        let loaded = WidgetSnapshotStore.load(defaults: defaults)
        #expect(loaded == original)
    }
}
