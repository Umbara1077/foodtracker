import Foundation

enum PrivacyConstants {
    /// Bump when the cloud-scan disclosure text changes materially.
    static let cloudAIConsentVersion = "2026-08-21"

    private static let fallbackPrivacy = URL(string: "https://example.com/project-plate/privacy")!
    private static let fallbackTerms = URL(string: "https://example.com/project-plate/terms")!
    private static let fallbackSupport = URL(string: "mailto:support@projectplate.app")!

    /// Prefer Info.plist `PLATE_PRIVACY_POLICY_URL` so TestFlight / Release can point at a real host without a code change.
    static var privacyPolicyURL: URL {
        url(infoKey: "PLATE_PRIVACY_POLICY_URL", fallback: fallbackPrivacy)
    }

    /// Prefer Info.plist `PLATE_TERMS_URL`.
    static var termsURL: URL {
        url(infoKey: "PLATE_TERMS_URL", fallback: fallbackTerms)
    }

    /// Prefer Info.plist `PLATE_SUPPORT_URL` (https page or mailto:).
    static var supportURL: URL {
        url(infoKey: "PLATE_SUPPORT_URL", fallback: fallbackSupport)
    }

    /// True when either legal URL still points at the example.com placeholder.
    static var usesPlaceholderLegalURLs: Bool {
        isPlaceholder(privacyPolicyURL) || isPlaceholder(termsURL)
    }

    /// True when Support still uses the shipping placeholder mailbox.
    static var usesPlaceholderSupportURL: Bool {
        supportURL.absoluteString.localizedCaseInsensitiveContains("support@projectplate.app")
    }

    static func isPlaceholder(_ url: URL) -> Bool {
        (url.host ?? "").localizedCaseInsensitiveContains("example.com")
    }

    static func url(infoKey: String, fallback: URL, bundle: Bundle = .main) -> URL {
        url(fromRaw: bundle.object(forInfoDictionaryKey: infoKey) as? String, fallback: fallback)
    }

    static func url(fromRaw raw: String?, fallback: URL) -> URL {
        guard let raw else { return fallback }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = URL(string: trimmed), parsed.scheme != nil else {
            return fallback
        }
        return parsed
    }
}

enum AppVersion {
    static func marketing(bundle: Bundle = .main) -> String {
        string(forKey: "CFBundleShortVersionString", bundle: bundle) ?? "—"
    }

    static func build(bundle: Bundle = .main) -> String {
        string(forKey: "CFBundleVersion", bundle: bundle) ?? "—"
    }

    static func display(bundle: Bundle = .main) -> String {
        "\(marketing(bundle: bundle)) (\(build(bundle: bundle)))"
    }

    static func display(marketing: String, build: String) -> String {
        "\(marketing) (\(build))"
    }

    private static func string(forKey key: String, bundle: Bundle) -> String? {
        bundle.object(forInfoDictionaryKey: key) as? String
    }
}

struct CloudAIConsentCopy {
    static let title = "Cloud meal analysis"
    static let body = """
    With your permission, Project Plate can send a meal photo to our managed analysis gateway (which may use a third-party model provider such as OpenAI) to identify foods and estimate portions.

    We re-encode the photo as a compressed JPEG so camera EXIF/GPS metadata is not included, and we send a request ID and schema version. We do not permanently store standard scan photos on our servers. The model provider’s retention rules may still apply to the request in transit — see the Privacy Policy.

    If you choose Not now, photo scan still works with on-device analysis. Manual search, barcode, quick add, and your diary keep working either way. You can change this later in Settings → Privacy.
    """
}

protocol CrashReporting: Sendable {
    func record(error: Error, context: String)
    func breadcrumb(_ message: String)
}

struct LoggingCrashReporter: CrashReporting {
    func record(error: Error, context: String) {
        // Privacy: never log meal photos, Health samples, or raw request bodies.
        #if DEBUG
        print("[CrashReporter] \(context): \(error.localizedDescription)")
        #endif
    }

    func breadcrumb(_ message: String) {
        #if DEBUG
        print("[Breadcrumb] \(message)")
        #endif
    }
}

/// Analytics wrapper that only accepts typed events (no free-form PII strings).
struct PrivacyAnalyticsClient: AnalyticsClient {
    private let inner: any AnalyticsClient
    private let crashReporter: any CrashReporting

    init(inner: any AnalyticsClient = NoOpAnalyticsClient(), crashReporter: any CrashReporting = LoggingCrashReporter()) {
        self.inner = inner
        self.crashReporter = crashReporter
    }

    func track(_ event: AnalyticsEvent) {
        crashReporter.breadcrumb("analytics.\(String(describing: event))")
        inner.track(event)
    }
}

enum DataMaintenanceError: Error, LocalizedError, Sendable {
    case exportFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed: "Could not export your data."
        case .deleteFailed: "Could not delete local data."
        }
    }
}

struct DiaryExportPayload: Codable, Sendable {
    var exportedAt: Date
    var consentVersion: String?
    var profile: UserProfile?
    var meals: [MealRecord]
    var weights: [WeightEntry]
    var targets: [NutritionTargetSnapshot]
}

struct DataMaintenanceService: Sendable {
    var mealRepository: any MealRepository
    var weightRepository: any WeightRepository
    var profileRepository: any ProfileRepository
    var targetRepository: any TargetRepository
    var savedMealRepository: any SavedMealRepository
    /// When set, Delete uploads iCloud tombstones before wiping local rows.
    var diarySync: DiarySyncCoordinator? = nil

    func exportJSON(calendar: Calendar = .current) async throws -> Data {
        let profile = try await profileRepository.loadProfile()
        let end = Date()
        let start = calendar.date(byAdding: .year, value: -5, to: end) ?? end
        // Gather meals day-by-day for the export window.
        var meals: [MealRecord] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            meals.append(contentsOf: try await mealRepository.meals(on: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        let weights = try await weightRepository.entries(from: start, to: end)
        let targets = try await targetRepository.allTargets()
        let payload = DiaryExportPayload(
            exportedAt: .now,
            consentVersion: profile?.cloudAIConsentVersion,
            profile: profile.map(sanitizedProfile),
            meals: meals,
            weights: weights,
            targets: targets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(payload)
        } catch {
            throw DataMaintenanceError.exportFailed
        }
    }

    /// Flat meal diary CSV for spreadsheets (PRODUCT_SPEC §6.1).
    func exportCSV(calendar: Calendar = .current) async throws -> Data {
        let end = Date()
        let start = calendar.date(byAdding: .year, value: -5, to: end) ?? end
        var meals: [MealRecord] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            meals.append(contentsOf: try await mealRepository.meals(on: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        meals.sort { $0.eatenAt < $1.eatenAt }
        let csv = DiaryCSVExporter.csv(from: meals)
        guard let data = csv.data(using: .utf8) else { throw DataMaintenanceError.exportFailed }
        return data
    }

    func deleteAllLocalData(purgeCloudCopies: Bool = true) async throws {
        // Coordinator owns the UserDefaults suite for sync preference — do not check `.standard` here.
        if purgeCloudCopies, let diarySync {
            try await diarySync.uploadTombstonesForAllLocalRecords()
        }

        // Best-effort wipe across repositories.
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .year, value: -10, to: end) ?? end
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            let meals = try await mealRepository.meals(on: cursor, calendar: calendar)
            for meal in meals {
                try await mealRepository.delete(id: meal.id)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        let weights = try await weightRepository.entries(from: start, to: end)
        for weight in weights {
            try await weightRepository.delete(id: weight.id)
        }
        try await savedMealRepository.clear()
        // Reset profile consent / flags but keep a blank local profile shell.
        var blank = UserProfile.blank
        blank.onboardingComplete = false
        try await profileRepository.saveProfile(blank)
        CloudAIConsentStore.clear()
        CloudSyncPreference.setChangeToken(nil)
        CloudSyncPreference.setLastSyncDate(nil)
    }

    private func sanitizedProfile(_ profile: UserProfile) -> UserProfile {
        // Export includes health metrics the user owns; strip nothing beyond what's stored.
        profile
    }
}
