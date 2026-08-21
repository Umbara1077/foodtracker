import Foundation

struct AIModelConfiguration: Sendable, Equatable {
    var primaryModel: String
    var escalationModel: String
    var freeDailyScans: Int
    var maxImageBytes: Int
    var providerMode: String

    static let `default` = AIModelConfiguration(
        primaryModel: "gpt-5.6-luna",
        escalationModel: "gpt-5.6-terra",
        freeDailyScans: 5,
        maxImageBytes: 2_500_000,
        providerMode: "mock"
    )
}

struct BackendConfiguration: Sendable, Equatable {
    /// Empty means use on-device mock (no network). Set via Info.plist `PLATE_API_BASE_URL`, custom gateway, or DEBUG override.
    var baseURL: URL?
    var appToken: String?
    var installID: String
    /// `managed` (Info.plist), `custom` (user gateway), or `mock`.
    var sourceLabel: String = "mock"

    var isCloudEnabled: Bool { baseURL != nil }

    /// Prefer an enabled custom gateway; otherwise fall back to Info.plist managed backend.
    static func resolved(installID: String = InstallIdentity.shared.id, defaults: UserDefaults = .standard) -> BackendConfiguration {
        if CustomGatewayStore.isEnabled(defaults: defaults),
           let url = CustomGatewayStore.endpointURL(defaults: defaults) {
            return BackendConfiguration(
                baseURL: url,
                appToken: CustomGatewayStore.loadToken(),
                installID: installID,
                sourceLabel: "custom"
            )
        }
        return load(installID: installID)
    }

    static func load(installID: String = InstallIdentity.shared.id) -> BackendConfiguration {
        let raw = Bundle.main.object(forInfoDictionaryKey: "PLATE_API_BASE_URL") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = (trimmed?.isEmpty == false) ? URL(string: trimmed!) : nil
        let token = Bundle.main.object(forInfoDictionaryKey: "PLATE_API_TOKEN") as? String
        let enabled = url != nil
        return BackendConfiguration(
            baseURL: url,
            appToken: (token?.isEmpty == false) ? token : nil,
            installID: installID,
            sourceLabel: enabled ? "managed" : "mock"
        )
    }
}

enum InstallIdentity {
    static let shared = InstallIdentityStore()
}

final class InstallIdentityStore: @unchecked Sendable {
    private let key = "plate.install_id"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var id: String {
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: key)
        return created
    }
}

final class ScanQuotaStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _remaining: Int?
    private var _dailyLimit: Int?

    var remaining: Int? {
        lock.lock(); defer { lock.unlock() }
        return _remaining
    }

    var dailyLimit: Int? {
        lock.lock(); defer { lock.unlock() }
        return _dailyLimit
    }

    func update(remaining: Int, dailyLimit: Int) {
        lock.lock()
        _remaining = remaining
        _dailyLimit = dailyLimit
        lock.unlock()
    }
}
