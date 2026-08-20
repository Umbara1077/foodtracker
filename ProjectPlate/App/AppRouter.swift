import Foundation
import Observation

/// Lightweight navigation coordinator for root-level presentations (scanner, onboarding).
@Observable
@MainActor
final class AppRouter {
    var selectedTab: RootTab = .today
    var isScannerPresented = false
    var needsOnboarding = true
    var isBootstrapping = true

    func openScanner() {
        isScannerPresented = true
    }

    func dismissScanner() {
        isScannerPresented = false
    }

    func completeOnboarding() {
        needsOnboarding = false
    }
}

enum RootTab: Hashable, CaseIterable, Identifiable {
    case today
    case history
    case progress
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .progress: "Progress"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .history: "calendar"
        case .progress: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        }
    }
}
