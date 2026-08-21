import Foundation

/// Persists Accept / Decline for the current cloud-AI consent version (Guideline 5.1.1).
enum CloudAIConsentStore {
    enum Decision: String, Sendable, Equatable {
        case accepted
        case declined
    }

    private static let decisionKey = "plate.cloudAI.decision"
    private static let versionKey = "plate.cloudAI.decisionVersion"

    static func decision(defaults: UserDefaults = .standard) -> Decision? {
        guard defaults.string(forKey: versionKey) == PrivacyConstants.cloudAIConsentVersion,
              let raw = defaults.string(forKey: decisionKey),
              let value = Decision(rawValue: raw)
        else { return nil }
        return value
    }

    static func set(_ decision: Decision, defaults: UserDefaults = .standard) {
        defaults.set(decision.rawValue, forKey: decisionKey)
        defaults.set(PrivacyConstants.cloudAIConsentVersion, forKey: versionKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: decisionKey)
        defaults.removeObject(forKey: versionKey)
    }

    /// True when the user has not yet answered for the current consent copy version.
    static func needsPrompt(defaults: UserDefaults = .standard) -> Bool {
        decision(defaults: defaults) == nil
    }

    /// Cloud upload is allowed only after an explicit Accept for this version.
    static func allowsCloudUpload(defaults: UserDefaults = .standard) -> Bool {
        decision(defaults: defaults) == .accepted
    }

    static func statusLabel(defaults: UserDefaults = .standard) -> String {
        switch decision(defaults: defaults) {
        case .accepted: "Accepted (\(PrivacyConstants.cloudAIConsentVersion))"
        case .declined: "Declined — on-device analysis only"
        case nil: "Not answered"
        }
    }
}

enum BuildChannel {
    /// Sandbox receipt means TestFlight (or local StoreKit testing).
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    static var showsBetaTools: Bool {
        #if DEBUG
        true
        #else
        isTestFlight
        #endif
    }
}
