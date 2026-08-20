import Foundation
import StoreKit

/// StoreKit 2 purchase manager. Entitlement comes from transaction updates, not a lone cached bool.
actor StoreKitPurchaseManager: SubscriptionServicing {
    private var cachedEntitlement: ProEntitlement = .free
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task {
            for await update in Transaction.updates {
                if let transaction = try? checkVerified(update) {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            }
        }
        Task { await refreshEntitlements() }
    }

    func currentEntitlement() async -> ProEntitlement {
        await refreshEntitlements()
        return cachedEntitlement
    }

    func loadProducts() async throws -> [SubscriptionProductInfo] {
        let products = try await Product.products(for: SubscriptionProductID.all)
        return products
            .sorted { lhs, rhs in
                // Prefer annual first for display order.
                (lhs.id == SubscriptionProductID.annual ? 0 : 1)
                    < (rhs.id == SubscriptionProductID.annual ? 0 : 1)
            }
            .map { product in
                SubscriptionProductInfo(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    periodLabel: periodLabel(for: product),
                    isAnnual: product.id == SubscriptionProductID.annual
                )
            }
    }

    func purchase(productID: String) async throws -> ProEntitlement {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw PurchaseError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return await refreshEntitlements()
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.purchaseFailed
        }
    }

    func restore() async throws -> ProEntitlement {
        try await AppStore.sync()
        return await refreshEntitlements()
    }

    @discardableResult
    private func refreshEntitlements() async -> ProEntitlement {
        var best: ProEntitlement = .free
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard SubscriptionProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { continue }
            best = .pro(expiration: transaction.expirationDate)
        }
        cachedEntitlement = best
        return best
    }

    private func periodLabel(for product: Product) -> String {
        guard let sub = product.subscription else { return "Subscription" }
        switch sub.subscriptionPeriod.unit {
        case .month:
            let value = sub.subscriptionPeriod.value
            return value == 1 ? "Monthly" : "Every \(value) months"
        case .year:
            let value = sub.subscriptionPeriod.value
            return value == 1 ? "Annual" : "Every \(value) years"
        case .week:
            return "Weekly"
        case .day:
            return "Daily"
        @unknown default:
            return "Subscription"
        }
    }
}

private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
        throw PurchaseError.purchaseFailed
    case .verified(let safe):
        return safe
    }
}

/// Deterministic fake for previews/tests/CI without App Store.
actor MockPurchaseManager: SubscriptionServicing {
    private var entitlement: ProEntitlement
    private let products: [SubscriptionProductInfo]

    init(entitlement: ProEntitlement = .free) {
        self.entitlement = entitlement
        self.products = [
            SubscriptionProductInfo(
                id: SubscriptionProductID.annual,
                displayName: "Pro Annual",
                displayPrice: "$39.99",
                periodLabel: "Annual",
                isAnnual: true
            ),
            SubscriptionProductInfo(
                id: SubscriptionProductID.monthly,
                displayName: "Pro Monthly",
                displayPrice: "$7.99",
                periodLabel: "Monthly",
                isAnnual: false
            ),
        ]
    }

    func currentEntitlement() async -> ProEntitlement { entitlement }

    func loadProducts() async throws -> [SubscriptionProductInfo] { products }

    func purchase(productID: String) async throws -> ProEntitlement {
        guard products.contains(where: { $0.id == productID }) else {
            throw PurchaseError.productUnavailable
        }
        entitlement = .pro(expiration: Calendar.current.date(byAdding: .year, value: 1, to: .now))
        return entitlement
    }

    func restore() async throws -> ProEntitlement { entitlement }

    func setEntitlement(_ value: ProEntitlement) {
        entitlement = value
    }
}
