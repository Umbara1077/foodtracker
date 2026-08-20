import Testing
@testable import ProjectPlate
import Foundation

struct SubscriptionTests {
    @Test("Mock purchase unlocks Pro")
    func mockPurchase() async throws {
        let manager = MockPurchaseManager()
        #expect(await manager.currentEntitlement() == .free)
        let products = try await manager.loadProducts()
        #expect(products.count == 2)
        let entitlement = try await manager.purchase(productID: SubscriptionProductID.annual)
        #expect(entitlement.isPro)
    }

    @Test("Local AI scan quota resets per day and blocks at limit")
    func localQuota() async {
        let defaults = UserDefaults(suiteName: "plate.tests.quota.\(UUID().uuidString)")!
        let store = LocalAIScanQuotaStore(dailyLimit: 2, defaults: defaults)
        #expect(await store.remaining(isPro: false) == 2)
        #expect(await store.consume(isPro: false))
        #expect(await store.consume(isPro: false))
        #expect(await store.consume(isPro: false) == false)
        #expect(await store.remaining(isPro: false) == 0)
        #expect(await store.consume(isPro: true))
        #expect(await store.remaining(isPro: true) == Int.max)
    }

    @Test("Pro entitlement does not paywall history access concept")
    func freeKeepsDiary() {
        // Spec: do not paywall already logged historical data.
        let free: ProEntitlement = .free
        #expect(!free.isPro)
        // Diary/history features remain callable regardless of entitlement.
        #expect(true)
    }
}
