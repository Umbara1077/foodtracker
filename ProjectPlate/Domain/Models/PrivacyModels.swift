import Foundation

enum PrivacyConstants {
    /// Bump when the cloud-scan disclosure text changes materially.
    static let cloudAIConsentVersion = "2026-08-20"
    static let privacyPolicyURL = URL(string: "https://example.com/project-plate/privacy")!
    static let termsURL = URL(string: "https://example.com/project-plate/terms")!
}

struct CloudAIConsentCopy {
    static let title = "Cloud meal analysis"
    static let body = """
    Meal photos can be sent to our AI provider to identify food. We send only what is needed for the scan — a compressed image without location metadata, plus a request ID and schema version. We do not permanently store meal photos on our servers for standard scans.

    Manual search, barcode, quick add, and your diary keep working if you decline.
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

    func deleteAllLocalData() async throws {
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
    }

    private func sanitizedProfile(_ profile: UserProfile) -> UserProfile {
        // Export includes health metrics the user owns; strip nothing beyond what's stored.
        profile
    }
}
