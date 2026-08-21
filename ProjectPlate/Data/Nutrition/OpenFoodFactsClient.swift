import Foundation

/// Open Food Facts product lookup (no API key). Used only after local barcode miss.
struct OpenFoodFactsClient: Sendable {
    var urlSession: URLSession
    var baseURL: URL

    init(
        urlSession: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org")!
    ) {
        self.urlSession = urlSession
        self.baseURL = baseURL
    }

    func lookup(barcode: String) async throws -> NutritionFood? {
        let code = BarcodeNormalizer.normalize(barcode)
        guard BarcodeNormalizer.isPlausible(code) else { return nil }

        let url = baseURL.appending(path: "api/v2/product/\(code).json")
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("ProjectPlate/0.6 (nutrition tracker; educational)", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw NutritionRepositoryError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else {
            throw NutritionRepositoryError.networkUnavailable
        }

        let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else { return nil }
        return product.asNutritionFood(barcode: code)
    }
}

private struct OFFProductResponse: Decodable {
    var status: Int
    var product: OFFProduct?
}

private struct OFFProduct: Decodable {
    var productName: String?
    var brands: String?
    var nutriments: OFFNutriments?
    var servingQuantity: Double?
    var servingSize: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
        case servingQuantity = "serving_quantity"
        case servingSize = "serving_size"
    }

    func asNutritionFood(barcode: String) -> NutritionFood? {
        guard let nutriments else { return nil }
        let calories = nutriments.energyKcal100g ?? nutriments.energyKcalValue
        let protein = nutriments.proteins100g
        let carbs = nutriments.carbohydrates100g
        let fat = nutriments.fat100g
        guard let calories, let protein, let carbs, let fat else { return nil }

        let name = (productName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? "Packaged food"
        let brand = brands?.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let servingGrams = servingQuantity.flatMap { $0 > 0 ? $0 : nil } ?? 100

        return NutritionFood(
            id: "off.\(barcode)",
            source: .openFoodFacts,
            name: name,
            brand: brand?.isEmpty == true ? nil : brand,
            serving: ServingDescriptor(
                label: servingSize?.isEmpty == false ? servingSize! : "serving",
                grams: servingGrams
            ),
            per100g: NutrientSet(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: nutriments.fiber100g,
                sugar: nutriments.sugars100g,
                sodiumMg: nutriments.sodium100g.map { $0 * 1000 }
            )
        )
    }
}

private struct OFFNutriments: Decodable {
    var energyKcal100g: Double?
    var energyKcalValue: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var fat100g: Double?
    var fiber100g: Double?
    var sugars100g: Double?
    var sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalValue = "energy-kcal_value"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
    }
}
