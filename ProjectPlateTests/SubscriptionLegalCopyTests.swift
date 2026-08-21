import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 33 — App Review billing disclosures")
struct SubscriptionLegalCopyTests {
    @Test("Subscribe CTA includes price and period")
    func subscribeTitle() {
        #expect(
            SubscriptionLegalCopy.subscribeButtonTitle(
                displayPrice: "$39.99",
                isAnnual: true,
                isPurchasing: false
            ) == "Subscribe — $39.99/year"
        )
        #expect(
            SubscriptionLegalCopy.subscribeButtonTitle(
                displayPrice: "$7.99",
                isAnnual: false,
                isPurchasing: false
            ) == "Subscribe — $7.99/month"
        )
        #expect(
            SubscriptionLegalCopy.subscribeButtonTitle(
                displayPrice: "$7.99",
                isAnnual: false,
                isPurchasing: true
            ) == "Working…"
        )
    }

    @Test("Selected plan disclosure names service, period, and auto-renew")
    func selectedPlanDisclosure() {
        let line = SubscriptionLegalCopy.selectedPlanDisclosure(
            displayPrice: "$39.99",
            periodLabel: "Annual",
            isAnnual: true
        )
        #expect(line.contains("Project Plate Pro"))
        #expect(line.contains("Annual"))
        #expect(line.contains("$39.99/year"))
        #expect(line.contains("Auto-renewable"))
    }

    @Test("Auto-renew summary covers Apple 3.1.2 required points")
    func autoRenewSummary() {
        let copy = SubscriptionLegalCopy.autoRenewSummary.lowercased()
        #expect(copy.contains("apple id"))
        #expect(copy.contains("automatically"))
        #expect(copy.contains("24 hours"))
        #expect(copy.contains("manage") || copy.contains("cancel"))
    }

    @Test("Manage subscriptions URL is App Store account subscriptions")
    func manageURL() {
        #expect(SubscriptionLegalCopy.manageSubscriptionsURL.host == "apps.apple.com")
        #expect(SubscriptionLegalCopy.manageSubscriptionsURL.path.contains("subscriptions"))
    }
}
