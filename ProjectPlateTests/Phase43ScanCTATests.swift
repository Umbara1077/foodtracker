import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 43 — Scan primary CTA")
struct Phase43ScanCTATests {
    @Test("Consent wins before quota and scanner")
    func consentFirst() {
        #expect(ScanLaunchGate.decide(needsConsent: true, remainingScans: 5) == .consent)
        #expect(ScanLaunchGate.decide(needsConsent: true, remainingScans: 0) == .consent)
    }

    @Test("Exhausted quota opens paywall when consent is settled")
    func paywallWhenEmpty() {
        #expect(ScanLaunchGate.decide(needsConsent: false, remainingScans: 0) == .paywall)
        #expect(ScanLaunchGate.decide(needsConsent: false, remainingScans: -1) == .paywall)
    }

    @Test("Remaining scans open the scanner")
    func scannerWhenReady() {
        #expect(ScanLaunchGate.decide(needsConsent: false, remainingScans: 1) == .scanner)
        #expect(ScanLaunchGate.decide(needsConsent: false, remainingScans: 10) == .scanner)
    }
}
