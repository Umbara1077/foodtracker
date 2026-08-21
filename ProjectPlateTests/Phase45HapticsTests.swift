import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 45 — Haptics")
struct Phase45HapticsTests {
    @Test("Shutter uses medium impact")
    func shutter() {
        #expect(PlateHaptics.kind(for: .shutter) == .impactMedium)
    }

    @Test("Success events use success notification")
    func successEvents() {
        #expect(PlateHaptics.kind(for: .scanSuccess) == .notificationSuccess)
        #expect(PlateHaptics.kind(for: .mealSaved) == .notificationSuccess)
        #expect(PlateHaptics.kind(for: .purchaseSuccess) == .notificationSuccess)
    }

    @Test("Delete and warning use warning notification")
    func warningEvents() {
        #expect(PlateHaptics.kind(for: .mealDeleted) == .notificationWarning)
        #expect(PlateHaptics.kind(for: .warning) == .notificationWarning)
    }

    @Test("Selection uses selection feedback")
    func selection() {
        #expect(PlateHaptics.kind(for: .selection) == .selection)
    }
}
