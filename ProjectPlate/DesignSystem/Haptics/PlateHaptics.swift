import UIKit

/// Central haptic mapping (PRODUCT_SPEC §8.7). Call sites should use `play` instead of raw generators.
enum PlateHaptics {
    enum Event: String, Sendable, Equatable {
        case shutter
        case scanSuccess
        case mealSaved
        case mealDeleted
        case warning
        case selection
        case purchaseSuccess
    }

    enum Kind: String, Sendable, Equatable {
        case impactMedium
        case impactLight
        case notificationSuccess
        case notificationWarning
        case selection
    }

    static func kind(for event: Event) -> Kind {
        switch event {
        case .shutter: return .impactMedium
        case .scanSuccess, .mealSaved, .purchaseSuccess: return .notificationSuccess
        case .mealDeleted, .warning: return .notificationWarning
        case .selection: return .selection
        }
    }

    @MainActor
    static func play(_ event: Event) {
        switch kind(for: event) {
        case .impactMedium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .impactLight:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .notificationSuccess:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .notificationWarning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
