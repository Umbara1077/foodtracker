import Foundation

/// HTTP client for `/v1/meal/analyze`. Never embeds OpenAI keys — uses managed or custom gateway config.
struct ManagedCloudVisionProvider: MealVisionProvider {
    let id = "managed-cloud"
    /// When set, used instead of `configurationProvider` (unit tests).
    var configurationOverride: BackendConfiguration?
    var configurationProvider: @Sendable () -> BackendConfiguration
    var urlSession: URLSession
    var onQuotaUpdate: (@Sendable (Int, Int) -> Void)?

    init(
        configuration: BackendConfiguration? = nil,
        configurationProvider: @escaping @Sendable () -> BackendConfiguration = { BackendConfiguration.resolved() },
        urlSession: URLSession = .shared,
        onQuotaUpdate: (@Sendable (Int, Int) -> Void)? = nil
    ) {
        self.configurationOverride = configuration
        self.configurationProvider = configurationProvider
        self.urlSession = urlSession
        self.onQuotaUpdate = onQuotaUpdate
    }

    func analyze(imageData: Data, context: MealAnalysisContext) async throws -> VisionMealDraft {
        let configuration = configurationOverride ?? configurationProvider()
        guard let baseURL = configuration.baseURL else {
            throw MealScanError.providerUnavailable
        }
        guard !imageData.isEmpty else { throw MealScanError.invalidImage }

        let endpoint = baseURL.appending(path: "v1/meal/analyze")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-Plate-Schema-Version")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        request.setValue(configuration.installID, forHTTPHeaderField: "X-Install-ID")
        if let token = configuration.appToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = AnalyzeAPIRequest(
            imageBase64: imageData.base64EncodedString(),
            mimeType: "image/jpeg",
            mealHint: context.mealHint?.rawValue,
            locale: context.localeIdentifier,
            units: context.units == .metric ? "metric" : "imperial"
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw MealScanError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw MealScanError.providerUnavailable
        }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw MealScanError.unauthorized
        case 429:
            throw MealScanError.quotaExceeded
        case 400, 422:
            throw MealScanError.invalidStructuredResponse
        default:
            throw MealScanError.providerUnavailable
        }

        let decoded: AnalyzeAPIResponse
        do {
            decoded = try JSONDecoder().decode(AnalyzeAPIResponse.self, from: data)
        } catch {
            throw MealScanError.invalidStructuredResponse
        }

        onQuotaUpdate?(decoded.quota.remaining, decoded.quota.dailyLimit)

        let draft = VisionMealDraft(
            schemaVersion: decoded.draft.schemaVersion,
            mealName: decoded.draft.mealName,
            items: decoded.draft.items.map {
                VisionFoodItem(
                    id: UUID(uuidString: $0.id ?? "") ?? UUID(),
                    displayName: $0.displayName,
                    canonicalQuery: $0.canonicalQuery,
                    estimatedGrams: $0.estimatedGrams,
                    gramRangeLow: $0.gramRangeLow,
                    gramRangeHigh: $0.gramRangeHigh,
                    preparation: $0.preparation,
                    brandOrRestaurant: $0.brandOrRestaurant,
                    visibleAdditions: $0.visibleAdditions ?? [],
                    confidence: $0.confidence
                )
            },
            overallConfidence: decoded.draft.overallConfidence,
            clarifyingQuestion: decoded.draft.clarifyingQuestion,
            uncertaintyNotes: decoded.draft.uncertaintyNotes ?? []
        )
        return try VisionDraftValidator.validate(draft)
    }

    /// Lightweight connectivity check for Settings → Advanced (10s timeout).
    static func testConnection(
        baseURL: URL,
        token: String?,
        installID: String = InstallIdentity.shared.id,
        urlSession: URLSession = .shared
    ) async throws {
        let endpoint = baseURL.appending(path: "v1/meal/analyze")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-Plate-Schema-Version")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        request.setValue(installID, forHTTPHeaderField: "X-Install-ID")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Tiny JPEG so the gateway can validate auth / schema without a real meal photo.
        let probe = MealImageEncoder.minimalPrivacySafeJPEG
        let body = AnalyzeAPIRequest(
            imageBase64: probe.base64EncodedString(),
            mimeType: "image/jpeg",
            mealHint: nil,
            locale: Locale.current.identifier,
            units: "metric"
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await urlSession.data(for: request)
        } catch {
            throw CustomGatewayError.testFailed("Could not reach the gateway.")
        }
        guard let http = response as? HTTPURLResponse else {
            throw CustomGatewayError.testFailed("Unexpected gateway response.")
        }
        switch http.statusCode {
        case 200, 400, 422:
            // Reachable + accepted or schema-rejected still proves the endpoint exists.
            return
        case 401:
            throw CustomGatewayError.testFailed("Gateway rejected the token (401).")
        case 404:
            throw CustomGatewayError.testFailed("Gateway path /v1/meal/analyze was not found.")
        default:
            throw CustomGatewayError.testFailed("Gateway returned HTTP \(http.statusCode).")
        }
    }
}

// MARK: - Wire models (snake_case API contract)

private struct AnalyzeAPIRequest: Encodable {
    var imageBase64: String
    var mimeType: String
    var mealHint: String?
    var locale: String
    var units: String

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case mimeType = "mime_type"
        case mealHint = "meal_hint"
        case locale
        case units
    }
}

private struct AnalyzeAPIResponse: Decodable {
    var requestId: String
    var provider: String
    var model: String
    var latencyMs: Int
    var draft: DraftDTO
    var quota: QuotaDTO

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case provider
        case model
        case latencyMs = "latency_ms"
        case draft
        case quota
    }

    struct QuotaDTO: Decodable {
        var remaining: Int
        var dailyLimit: Int

        enum CodingKeys: String, CodingKey {
            case remaining
            case dailyLimit = "daily_limit"
        }
    }

    struct DraftDTO: Decodable {
        var schemaVersion: Int
        var mealName: String
        var items: [ItemDTO]
        var overallConfidence: Double
        var clarifyingQuestion: String?
        var uncertaintyNotes: [String]?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case mealName = "meal_name"
            case items
            case overallConfidence = "overall_confidence"
            case clarifyingQuestion = "clarifying_question"
            case uncertaintyNotes = "uncertainty_notes"
        }
    }

    struct ItemDTO: Decodable {
        var id: String?
        var displayName: String
        var canonicalQuery: String
        var estimatedGrams: Double
        var gramRangeLow: Double
        var gramRangeHigh: Double
        var preparation: String?
        var brandOrRestaurant: String?
        var visibleAdditions: [String]?
        var confidence: Double

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case canonicalQuery = "canonical_query"
            case estimatedGrams = "estimated_grams"
            case gramRangeLow = "gram_range_low"
            case gramRangeHigh = "gram_range_high"
            case preparation
            case brandOrRestaurant = "brand_or_restaurant"
            case visibleAdditions = "visible_additions"
            case confidence
        }
    }
}
