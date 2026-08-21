import Testing
@testable import ProjectPlate
import Foundation

struct VisionDraftValidatorTests {
    @Test("Valid draft passes through with clamped confidence")
    func validDraft() throws {
        let draft = VisionMealDraft(
            mealName: "Bowl",
            items: [
                VisionFoodItem(
                    displayName: "Rice",
                    canonicalQuery: "white rice cooked",
                    estimatedGrams: 100,
                    gramRangeLow: 80,
                    gramRangeHigh: 120,
                    confidence: 1.4
                ),
            ],
            overallConfidence: -0.2
        )
        let validated = try VisionDraftValidator.validate(draft)
        #expect(validated.items.first?.confidence == 1)
        #expect(validated.overallConfidence == 0)
    }

    @Test("Inverted gram range fails")
    func invertedRange() {
        let draft = VisionMealDraft(
            mealName: "Bad",
            items: [
                VisionFoodItem(
                    displayName: "X",
                    canonicalQuery: "x",
                    estimatedGrams: 100,
                    gramRangeLow: 150,
                    gramRangeHigh: 50,
                    confidence: 0.5
                ),
            ],
            overallConfidence: 0.5
        )
        do {
            _ = try VisionDraftValidator.validate(draft)
            Issue.record("Expected invalidStructuredResponse")
        } catch let error as MealScanError {
            #expect(error == .invalidStructuredResponse)
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }

    @Test("Empty items are allowed for unclear plates")
    func emptyItems() throws {
        let draft = VisionMealDraft(mealName: "Empty", items: [], overallConfidence: 0.2)
        let validated = try VisionDraftValidator.validate(draft)
        #expect(validated.items.isEmpty)
    }
}

struct ManagedCloudVisionProviderTests {
    @Test("Decodes server contract and validates draft")
    func decodesContract() async throws {
        let json = """
        {
          "request_id": "abc",
          "provider": "mock",
          "model": "mock-fixture",
          "latency_ms": 12,
          "draft": {
            "schema_version": 1,
            "meal_name": "Chicken rice bowl",
            "overall_confidence": 0.82,
            "clarifying_question": null,
            "uncertainty_notes": ["Sauce approximate"],
            "items": [
              {
                "id": "00000000-0000-0000-0000-000000000001",
                "display_name": "Grilled chicken",
                "canonical_query": "chicken breast grilled",
                "estimated_grams": 135,
                "gram_range_low": 110,
                "gram_range_high": 160,
                "preparation": "grilled",
                "brand_or_restaurant": null,
                "visible_additions": [],
                "confidence": 0.9
              }
            ]
          },
          "quota": { "remaining": 4, "daily_limit": 5 }
        }
        """.data(using: .utf8)!

        let session = URLSession.mock(data: json, statusCode: 200)
        var capturedRemaining: Int?
        var capturedLimit: Int?
        let provider = ManagedCloudVisionProvider(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://api.example.com")!,
                appToken: "token",
                installID: "install-1"
            ),
            urlSession: session,
            onQuotaUpdate: { remaining, limit in
                capturedRemaining = remaining
                capturedLimit = limit
            }
        )

        let draft = try await provider.analyze(
            imageData: Data(repeating: 7, count: 8),
            context: .default
        )
        #expect(draft.mealName == "Chicken rice bowl")
        #expect(draft.items.count == 1)
        #expect(capturedRemaining == 4)
        #expect(capturedLimit == 5)
    }

    @Test("Maps 429 to quotaExceeded")
    func quotaExceeded() async {
        let session = URLSession.mock(
            data: #"{"error":{"code":"quota_exceeded","message":"done"}}"#.data(using: .utf8)!,
            statusCode: 429
        )
        let provider = ManagedCloudVisionProvider(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://api.example.com")!,
                appToken: nil,
                installID: "install-2"
            ),
            urlSession: session
        )
        do {
            _ = try await provider.analyze(imageData: Data([1]), context: .default)
            Issue.record("Expected quotaExceeded")
        } catch let error as MealScanError {
            #expect(error == .quotaExceeded)
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var responseData: Data = Data()
    static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func mock(data: Data, statusCode: Int) -> URLSession {
        MockURLProtocol.responseData = data
        MockURLProtocol.statusCode = statusCode
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
