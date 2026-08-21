import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 30 — Apple Watch glance")
struct WatchGlancePresenterTests {
    @Test("Empty snapshot asks user to open iPhone")
    func empty() {
        let content = WatchGlancePresenter.content(from: nil)
        #expect(content.emptyState)
        #expect(content.caloriesValue == "—")
        #expect(content.headline == "Project Plate")
    }

    @Test("Maps remaining calories and protein from widget snapshot")
    func mapsSnapshot() {
        let snapshot = TodayWidgetSnapshot(
            updatedAt: .now,
            remainingCalories: 420,
            eatenCalories: 1_560,
            targetCalories: 1_980,
            proteinGrams: 88,
            proteinTargetGrams: 140,
            mealCount: 3
        )
        let content = WatchGlancePresenter.content(from: snapshot)
        #expect(!content.emptyState)
        #expect(content.headline == "Remaining")
        #expect(content.caloriesValue == "420")
        #expect(content.proteinLine == "P 88/140g")
        #expect(content.mealsLine == "3 meals logged")
    }

    @Test("Over-target headline and absolute remaining display")
    func overTarget() {
        let snapshot = TodayWidgetSnapshot.placeholder
        let over = TodayWidgetSnapshot(
            updatedAt: snapshot.updatedAt,
            remainingCalories: -120,
            eatenCalories: snapshot.eatenCalories,
            targetCalories: snapshot.targetCalories,
            proteinGrams: snapshot.proteinGrams,
            proteinTargetGrams: snapshot.proteinTargetGrams,
            mealCount: 1
        )
        let content = WatchGlancePresenter.content(from: over)
        #expect(content.headline == "Over target")
        #expect(content.caloriesValue == "120")
        #expect(content.mealsLine == "1 meal logged")
    }
}
