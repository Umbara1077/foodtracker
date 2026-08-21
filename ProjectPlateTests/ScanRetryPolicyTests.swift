import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 13 — Scan retry / recovery")
struct ScanRetryPolicyTests {
    @Test("Transient errors auto-retry once")
    func autoRetryTransient() {
        #expect(ScanRetryPolicy.shouldAutoRetry(MealScanError.network))
        #expect(ScanRetryPolicy.shouldAutoRetry(MealScanError.providerUnavailable))
        #expect(ScanRetryPolicy.shouldAutoRetry(MealScanError.invalidStructuredResponse))
        #expect(ScanRetryPolicy.shouldAutoRetry(NSError(domain: "test", code: 1)))
    }

    @Test("Permanent errors do not auto-retry")
    func noAutoRetryPermanent() {
        #expect(!ScanRetryPolicy.shouldAutoRetry(MealScanError.quotaExceeded))
        #expect(!ScanRetryPolicy.shouldAutoRetry(MealScanError.unauthorized))
        #expect(!ScanRetryPolicy.shouldAutoRetry(MealScanError.invalidImage))
        #expect(!ScanRetryPolicy.shouldAutoRetry(MealScanError.permissionDenied))
        #expect(!ScanRetryPolicy.shouldAutoRetry(MealScanError.cancelled))
    }

    @Test("Manual retry allowed only for recoverable analysis failures")
    func manualRetry() {
        #expect(ScanRetryPolicy.canRetryAnalysis(after: MealScanError.network))
        #expect(!ScanRetryPolicy.canRetryAnalysis(after: MealScanError.quotaExceeded))
        #expect(!ScanRetryPolicy.canRetryAnalysis(after: MealScanError.invalidImage))
    }

    @Test("User messages stay product-safe")
    func userMessages() {
        let empty = ScanRetryPolicy.userMessage(for: MealScanError.invalidStructuredResponse, emptyPlate: true)
        #expect(empty.contains("couldn’t confidently find food"))
        #expect(!empty.lowercased().contains("stack"))
        let network = ScanRetryPolicy.userMessage(for: MealScanError.network)
        #expect(network.contains("connection") || network.contains("try again"))
    }

    @Test("Jitter stays in expected window")
    func jitter() {
        let value = ScanRetryPolicy.jitterNanoseconds(using: { 350_000_000 })
        #expect(value == 350_000_000)
    }
}
