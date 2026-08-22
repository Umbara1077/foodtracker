import Foundation
import SwiftUI

/// Lightweight navigation coordinator for root-level presentations (scanner, onboarding).
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: RootTab = .today
    @Published var isScannerPresented = false
    @Published var isPaywallPresented = false
    @Published var isConsentPresented = false
    @Published var needsOnboarding = true
    @Published var isBootstrapping = true

    func openScanner() {
        isScannerPresented = true
    }

    func dismissScanner() {
        isScannerPresented = false
    }

    func openPaywall() {
        isPaywallPresented = true
    }

    func dismissPaywall() {
        isPaywallPresented = false
    }

    func openConsent() {
        isConsentPresented = true
    }

    func dismissConsent() {
        isConsentPresented = false
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

private enum AppRouterKey: EnvironmentKey {
    @MainActor static let defaultValue = AppRouter()
}

extension EnvironmentValues {
    var appRouter: AppRouter {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }
}
