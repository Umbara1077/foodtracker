import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 32 — TestFlight / legal URL readiness")
struct ReleaseReadinessTests {
    @Test("Empty Info keys fall back to placeholder hosts")
    func fallbackPlaceholders() {
        #expect(PrivacyConstants.isPlaceholder(PrivacyConstants.privacyPolicyURL))
        #expect(PrivacyConstants.isPlaceholder(PrivacyConstants.termsURL))
        #expect(PrivacyConstants.usesPlaceholderLegalURLs)
    }

    @Test("Raw override wins when a valid URL is provided")
    func rawOverride() {
        let privacy = PrivacyConstants.url(
            fromRaw: "https://projectplate.app/privacy",
            fallback: URL(string: "https://example.com/privacy")!
        )
        let terms = PrivacyConstants.url(
            fromRaw: "https://projectplate.app/terms",
            fallback: URL(string: "https://example.com/terms")!
        )
        #expect(privacy.absoluteString == "https://projectplate.app/privacy")
        #expect(terms.absoluteString == "https://projectplate.app/terms")
        #expect(!PrivacyConstants.isPlaceholder(privacy))
        #expect(!PrivacyConstants.isPlaceholder(terms))
    }

    @Test("Blank override keeps fallback")
    func blankOverride() {
        let fallback = URL(string: "https://example.com/project-plate/privacy")!
        let url = PrivacyConstants.url(fromRaw: "   ", fallback: fallback)
        #expect(url == fallback)
        #expect(PrivacyConstants.url(fromRaw: nil, fallback: fallback) == fallback)
    }

    @Test("AppVersion display formats marketing and build")
    func appVersionDisplay() {
        #expect(AppVersion.display(marketing: "1.5.3", build: "38") == "1.5.3 (38)")
    }
}
