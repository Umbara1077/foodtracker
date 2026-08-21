import Foundation

/// Shared gate for opening the meal scanner (consent → quota → scanner/paywall).
enum ScanLaunchGate {
    enum Decision: Equatable, Sendable {
        case consent
        case paywall
        case scanner
    }

    /// Pure routing used by UI and tests (PRODUCT_SPEC §11.2 Scan primary CTA).
    static func decide(needsConsent: Bool, remainingScans: Int) -> Decision {
        if needsConsent { return .consent }
        if remainingScans <= 0 { return .paywall }
        return .scanner
    }

    @MainActor
    static func open(
        environment: AppEnvironment,
        router: AppRouter
    ) async {
        let needsConsent = CloudAIConsentStore.needsPrompt()
        let entitlement = await environment.subscriptions.currentEntitlement()
        let remaining = await environment.aiScanQuota.remaining(isPro: entitlement.isPro)
        switch decide(needsConsent: needsConsent, remainingScans: remaining) {
        case .consent:
            router.openConsent()
        case .paywall:
            environment.analytics.track(.paywallViewed)
            router.openPaywall()
        case .scanner:
            router.openScanner()
        }
    }
}
