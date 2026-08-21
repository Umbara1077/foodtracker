import Foundation
import Security

/// Advanced BYO meal-analysis gateway (PRODUCT_SPEC §26 / §64). Token stays in Keychain — never UserDefaults.
enum CustomGatewayStore {
    static let enabledKey = "plate.customGateway.enabled"
    static let urlKey = "plate.customGateway.url"
    private static let tokenService = "com.projectplate.app.custom-gateway"
    private static let tokenAccount = "gateway-token"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }

    static func endpointURL(defaults: UserDefaults = .standard) -> URL? {
        guard let raw = defaults.string(forKey: urlKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }
        return URL(string: raw)
    }

    static func setEndpointURLString(_ raw: String, defaults: UserDefaults = .standard) {
        defaults.set(raw.trimmingCharacters(in: .whitespacesAndNewlines), forKey: urlKey)
    }

    static func clearEndpoint(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: urlKey)
    }

    static func saveToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteToken()
            return
        }
        let data = Data(trimmed.utf8)
        deleteToken()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CustomGatewayError.keychainWriteFailed
        }
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func hasToken() -> Bool {
        loadToken() != nil
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func disconnect(defaults: UserDefaults = .standard) {
        setEnabled(false, defaults: defaults)
        clearEndpoint(defaults: defaults)
        deleteToken()
    }

    /// Validates user-entered gateway URL. Production requires HTTPS.
    static func validatedURL(from raw: String, allowHTTPInDebug: Bool = false) -> Result<URL, CustomGatewayError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidURL) }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), url.host != nil else {
            return .failure(.invalidURL)
        }
        if scheme == "https" { return .success(url) }
        #if DEBUG
        if allowHTTPInDebug, scheme == "http" { return .success(url) }
        #endif
        _ = allowHTTPInDebug
        return .failure(.httpsRequired)
    }
}

enum CustomGatewayError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case httpsRequired
    case keychainWriteFailed
    case testFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Enter a valid gateway URL."
        case .httpsRequired: "Gateway URL must use HTTPS."
        case .keychainWriteFailed: "Could not save the gateway token securely."
        case .testFailed(let message): message
        }
    }
}
