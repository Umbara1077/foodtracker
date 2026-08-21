import Foundation

enum ProEntitlement: Sendable, Equatable {
    case free
    case pro(expiration: Date?)

    var isPro: Bool {
        switch self {
        case .free: false
        case .pro: true
        }
    }
}

struct SubscriptionProductInfo: Identifiable, Sendable, Equatable {
    var id: String
    var displayName: String
    var displayPrice: String
    var periodLabel: String
    var isAnnual: Bool
}

enum SubscriptionProductID {
    static let monthly = "com.projectplate.pro.monthly"
    static let annual = "com.projectplate.pro.annual"
    static let all: [String] = [monthly, annual]
}

enum PurchaseError: Error, LocalizedError, Sendable, Equatable {
    case productUnavailable
    case purchaseFailed
    case userCancelled
    case pending

    var errorDescription: String? {
        switch self {
        case .productUnavailable: "Subscriptions aren’t available right now."
        case .purchaseFailed: "Purchase didn’t complete."
        case .userCancelled: "Purchase cancelled."
        case .pending: "Purchase is pending approval."
        }
    }
}

protocol SubscriptionServicing: Sendable {
    func currentEntitlement() async -> ProEntitlement
    func loadProducts() async throws -> [SubscriptionProductInfo]
    func purchase(productID: String) async throws -> ProEntitlement
    func restore() async throws -> ProEntitlement
}

/// Local free AI-scan counter (backend remains authoritative when cloud is enabled).
actor LocalAIScanQuotaStore {
    private let defaults: UserDefaults
    private let dayKey = "plate.ai_scan_day"
    private let countKey = "plate.ai_scan_count"
    var dailyLimit: Int

    init(dailyLimit: Int = 3, defaults: UserDefaults = .standard) {
        self.dailyLimit = dailyLimit
        self.defaults = defaults
    }

    func remaining(isPro: Bool) -> Int {
        if isPro { return .max }
        refreshDayIfNeeded()
        let used = defaults.integer(forKey: countKey)
        return max(0, dailyLimit - used)
    }

    func canConsume(isPro: Bool) -> Bool {
        remaining(isPro: isPro) > 0
    }

    @discardableResult
    func consume(isPro: Bool) -> Bool {
        if isPro { return true }
        refreshDayIfNeeded()
        let used = defaults.integer(forKey: countKey)
        guard used < dailyLimit else { return false }
        defaults.set(used + 1, forKey: countKey)
        return true
    }

    private func refreshDayIfNeeded() {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let today = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
        let stored = defaults.string(forKey: dayKey) ?? ""
        if stored != today {
            defaults.set(today, forKey: dayKey)
            defaults.set(0, forKey: countKey)
        }
    }
}
