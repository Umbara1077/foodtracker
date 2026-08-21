import Foundation

/// Apple Guideline 3.1.2 auto-renewable subscription disclosures (copy + helpers).
enum SubscriptionLegalCopy {
    static let serviceName = "Project Plate Pro"

    static let autoRenewSummary = """
    Payment is charged to your Apple ID at confirmation. Subscriptions automatically \
    renew unless cancelled at least 24 hours before the end of the current period. \
    Your account is charged for renewal within 24 hours prior to the end of the current \
    period. Manage or cancel anytime in Account Settings.
    """

    static let freeKeepsHistory = "Already logged meals and Free diary features stay available if you cancel."

    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    static func periodUnitLabel(isAnnual: Bool) -> String {
        isAnnual ? "year" : "month"
    }

    static func pricePeriodLine(displayPrice: String, isAnnual: Bool) -> String {
        "\(displayPrice)/\(periodUnitLabel(isAnnual: isAnnual))"
    }

    static func subscribeButtonTitle(displayPrice: String?, isAnnual: Bool, isPurchasing: Bool) -> String {
        if isPurchasing { return "Working…" }
        guard let displayPrice else { return "Subscribe" }
        return "Subscribe — \(pricePeriodLine(displayPrice: displayPrice, isAnnual: isAnnual))"
    }

    static func selectedPlanDisclosure(displayPrice: String, periodLabel: String, isAnnual: Bool) -> String {
        "\(serviceName) · \(periodLabel) · \(pricePeriodLine(displayPrice: displayPrice, isAnnual: isAnnual)). Auto-renewable."
    }
}
