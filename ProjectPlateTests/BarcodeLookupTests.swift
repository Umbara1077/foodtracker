import Testing
@testable import ProjectPlate
import Foundation

struct BarcodeLookupTests {
    @Test("Normalizer strips non-digits")
    func normalize() {
        #expect(BarcodeNormalizer.normalize("0123-4567 8905") == "012345678905")
        #expect(BarcodeNormalizer.isPlausible("012345678905"))
        #expect(!BarcodeNormalizer.isPlausible("123"))
    }

    @Test("Bundled catalog resolves known fixture barcodes")
    func bundledHit() async throws {
        let repo = LocalNutritionRepository(openFoodFacts: nil)
        let food = try await repo.lookupBarcode("012345678905")
        #expect(food?.name.lowercased().contains("yogurt") == true)
        #expect(food?.serving != nil)
    }

    @Test("Unknown barcode returns nil without inventing nutrition")
    func unknownMiss() async throws {
        let repo = LocalNutritionRepository(openFoodFacts: nil)
        let food = try await repo.lookupBarcode("0000000000000")
        #expect(food == nil)
    }

    @Test("Barcode cache returns same food on second lookup")
    func cache() async throws {
        let repo = LocalNutritionRepository(openFoodFacts: nil)
        let first = try await repo.lookupBarcode("0012000012345")
        let second = try await repo.lookupBarcode("0012000012345")
        #expect(first?.id == second?.id)
        #expect(first?.name.lowercased().contains("granola") == true)
    }

    @Test("Open Food Facts client maps a product payload")
    func offMapping() async throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Test Bar",
            "brands": "Acme",
            "serving_quantity": 40,
            "serving_size": "1 bar",
            "nutriments": {
              "energy-kcal_100g": 400,
              "proteins_100g": 20,
              "carbohydrates_100g": 30,
              "fat_100g": 15
            }
          }
        }
        """.data(using: .utf8)!

        let session = URLSession.barcodeMock(data: json, statusCode: 200)
        let client = OpenFoodFactsClient(
            urlSession: session,
            baseURL: URL(string: "https://example.com")!
        )
        let food = try await client.lookup(barcode: "3017620422003")
        #expect(food?.name == "Test Bar")
        #expect(food?.brand == "Acme")
        #expect(food?.source == .openFoodFacts)
        #expect(food?.per100g.calories == 400)
        #expect(food?.serving?.grams == 40)
    }
}

private final class BarcodeMockURLProtocol: URLProtocol, @unchecked Sendable {
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
    static func barcodeMock(data: Data, statusCode: Int) -> URLSession {
        BarcodeMockURLProtocol.responseData = data
        BarcodeMockURLProtocol.statusCode = statusCode
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BarcodeMockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
