import Foundation

protocol RecipeURLFetching: Sendable {
    func html(from url: URL) async throws -> String
}

struct URLSessionRecipeFetcher: RecipeURLFetching {
    func html(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("ProjectPlate/1.0 (recipe import; +https://example.com)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
                throw RecipeImportError.fetchFailed
            }
            guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
                throw RecipeImportError.unreadableHTML
            }
            return html
        } catch let error as RecipeImportError {
            throw error
        } catch {
            throw RecipeImportError.fetchFailed
        }
    }
}

struct RecipeURLImporter: Sendable {
    var fetcher: any RecipeURLFetching
    var nutritionRepository: any NutritionRepository
    var maxIngredients: Int

    init(
        fetcher: any RecipeURLFetching = URLSessionRecipeFetcher(),
        nutritionRepository: any NutritionRepository,
        maxIngredients: Int = 12
    ) {
        self.fetcher = fetcher
        self.nutritionRepository = nutritionRepository
        self.maxIngredients = maxIngredients
    }

    func importRecipe(from rawURL: String) async throws -> RecipeImportDraft {
        guard let url = Self.normalizedURL(from: rawURL) else {
            throw RecipeImportError.invalidURL
        }
        let html = try await fetcher.html(from: url)
        guard var draft = RecipeHTMLParser.parse(html: html, sourceURL: url) else {
            throw RecipeImportError.noRecipeFound
        }
        draft.nutrients = try await estimateNutrients(for: draft.ingredients)
        if draft.nutrients.calories <= 0 {
            draft.notes = [draft.notes, "Nutrition estimate unavailable — edit before saving."]
                .compactMap { $0 }
                .joined(separator: " ")
        }
        return draft
    }

    func estimateNutrients(for ingredients: [String]) async throws -> NutrientSet {
        var total = NutrientSet.zero
        for line in ingredients.prefix(maxIngredients) {
            let queryText = RecipeIngredientEstimator.searchQuery(for: line)
            guard !queryText.isEmpty else { continue }
            let grams = RecipeIngredientEstimator.estimatedGrams(for: line)
            let query = NutritionSearchQuery(
                text: queryText,
                brand: nil,
                preparation: nil,
                locale: .current
            )
            let candidates = try await nutritionRepository.search(query)
            guard let food = candidates.first?.food else { continue }
            total = total + NutritionResolver.nutrients(for: food, grams: grams)
        }
        return total
    }

    static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" {
            return url
        }
        if let url = URL(string: "https://\(trimmed)"), url.host != nil {
            return url
        }
        return nil
    }
}
