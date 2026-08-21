import Foundation

struct RecipeImportDraft: Equatable, Sendable {
    var title: String
    var sourceURL: URL?
    var servings: Double
    var ingredients: [String]
    var nutrients: NutrientSet
    var notes: String?

    var perServingNutrients: NutrientSet {
        let divisor = max(servings, 1)
        return NutrientSet(
            calories: (nutrients.calories / divisor).rounded(),
            protein: ((nutrients.protein / divisor) * 10).rounded() / 10,
            carbs: ((nutrients.carbs / divisor) * 10).rounded() / 10,
            fat: ((nutrients.fat / divisor) * 10).rounded() / 10,
            fiber: nutrients.fiber.map { (($0 / divisor) * 10).rounded() / 10 },
            sugar: nutrients.sugar.map { (($0 / divisor) * 10).rounded() / 10 },
            sodiumMg: nutrients.sodiumMg.map { ($0 / divisor).rounded() }
        )
    }

    func makeMeal(mealType: MealType = .inferred(), logServings: Double = 1) -> MealRecord {
        let factor = logServings / max(servings, 1)
        let scaled = NutrientSet(
            calories: (nutrients.calories * factor).rounded(),
            protein: ((nutrients.protein * factor) * 10).rounded() / 10,
            carbs: ((nutrients.carbs * factor) * 10).rounded() / 10,
            fat: ((nutrients.fat * factor) * 10).rounded() / 10
        )
        var noteParts: [String] = []
        if let sourceURL {
            noteParts.append("Imported from \(sourceURL.host ?? sourceURL.absoluteString)")
        }
        if !ingredients.isEmpty {
            let preview = ingredients.prefix(6).joined(separator: "; ")
            noteParts.append("Ingredients: \(preview)")
        }
        if let notes, !notes.isEmpty {
            noteParts.append(notes)
        }
        return MealRecord(
            mealType: mealType,
            title: title.isEmpty ? "Imported recipe" : title,
            notes: noteParts.isEmpty ? nil : noteParts.joined(separator: "\n"),
            nutrients: scaled,
            inputMethod: .recipeURL
        )
    }
}

enum RecipeImportError: Error, LocalizedError, Sendable {
    case invalidURL
    case fetchFailed
    case unreadableHTML
    case noRecipeFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Enter a full https:// recipe link."
        case .fetchFailed: "Couldn’t download that page."
        case .unreadableHTML: "That page didn’t return readable HTML."
        case .noRecipeFound: "No recipe ingredients found on that page."
        }
    }
}

/// Extracts Recipe structured data from HTML (JSON-LD first, light heuristics second).
enum RecipeHTMLParser {
    static func parse(html: String, sourceURL: URL? = nil) -> RecipeImportDraft? {
        if let fromJSON = parseJSONLD(html: html, sourceURL: sourceURL) {
            return fromJSON
        }
        return parseHeuristic(html: html, sourceURL: sourceURL)
    }

    static func parseJSONLD(html: String, sourceURL: URL?) -> RecipeImportDraft? {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let jsonText = ns.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonText.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let recipe = findRecipeObject(in: json) {
                return draft(from: recipe, sourceURL: sourceURL)
            }
        }
        return nil
    }

    private static func findRecipeObject(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if isRecipeType(dict["@type"]) { return dict }
            if let graph = dict["@graph"] as? [Any] {
                for node in graph {
                    if let found = findRecipeObject(in: node) { return found }
                }
            }
            for value in dict.values {
                if let found = findRecipeObject(in: value) { return found }
            }
        } else if let array = json as? [Any] {
            for item in array {
                if let found = findRecipeObject(in: item) { return found }
            }
        }
        return nil
    }

    private static func isRecipeType(_ value: Any?) -> Bool {
        if let string = value as? String {
            return string.lowercased().contains("recipe")
        }
        if let array = value as? [String] {
            return array.contains { $0.lowercased().contains("recipe") }
        }
        return false
    }

    private static func draft(from recipe: [String: Any], sourceURL: URL?) -> RecipeImportDraft? {
        let title = (recipe["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Imported recipe"
        let ingredients = normalizeIngredients(recipe["recipeIngredient"])
        guard !ingredients.isEmpty else { return nil }
        let servings = parseServings(recipe["recipeYield"]) ?? 1
        return RecipeImportDraft(
            title: title,
            sourceURL: sourceURL,
            servings: max(servings, 1),
            ingredients: ingredients,
            nutrients: .zero,
            notes: nil
        )
    }

    private static func normalizeIngredients(_ value: Any?) -> [String] {
        if let list = value as? [String] {
            return list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let string = value as? String {
            return string
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    private static func parseServings(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let string = value as? String {
            let digits = string.split(whereSeparator: { !$0.isNumber && $0 != "." && $0 != "/" })
            if let first = digits.first, let value = Double(first) { return value }
            let matcher = string.replacingOccurrences(of: ",", with: ".")
            if let match = matcher.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) {
                return Double(matcher[match])
            }
        }
        if let array = value as? [Any] {
            for item in array {
                if let parsed = parseServings(item) { return parsed }
            }
        }
        return nil
    }

    static func parseHeuristic(html: String, sourceURL: URL?) -> RecipeImportDraft? {
        let stripped = html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")

        let lines = stripped
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var ingredients: [String] = []
        var capturing = false
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("ingredient") && line.count < 40 {
                capturing = true
                continue
            }
            if capturing {
                if lower.contains("direction") || lower.contains("instruction") || lower.contains("method") {
                    break
                }
                if line.count > 3 && line.count < 160 {
                    ingredients.append(line)
                }
                if ingredients.count >= 30 { break }
            }
        }
        guard ingredients.count >= 2 else { return nil }
        let title = lines.first(where: { $0.count > 5 && $0.count < 80 }) ?? "Imported recipe"
        return RecipeImportDraft(
            title: title,
            sourceURL: sourceURL,
            servings: 1,
            ingredients: Array(ingredients.prefix(20)),
            nutrients: .zero,
            notes: "Parsed without structured recipe data — review nutrition."
        )
    }
}

/// Estimates grams from a free-text ingredient line (best-effort, not lab precision).
enum RecipeIngredientEstimator {
    static func estimatedGrams(for ingredientLine: String) -> Double {
        let lower = ingredientLine.lowercased()
        if let cup = matchNumber(in: lower, unitHints: ["cup", "cups"]) {
            return cup * 120
        }
        if let tbsp = matchNumber(in: lower, unitHints: ["tbsp", "tablespoon", "tablespoons"]) {
            return tbsp * 15
        }
        if let tsp = matchNumber(in: lower, unitHints: ["tsp", "teaspoon", "teaspoons"]) {
            return tsp * 5
        }
        if let oz = matchNumber(in: lower, unitHints: ["oz", "ounce", "ounces"]) {
            return oz * 28
        }
        if let g = matchNumber(in: lower, unitHints: ["g", "gram", "grams"]) {
            return g
        }
        if let lb = matchNumber(in: lower, unitHints: ["lb", "lbs", "pound", "pounds"]) {
            return lb * 454
        }
        if lower.contains("clove") { return 5 }
        if lower.contains("egg") { return 50 }
        return 50
    }

    static func searchQuery(for ingredientLine: String) -> String {
        var text = ingredientLine.lowercased()
        let noise = [
            #"\d+/\d+"#, #"\d+(\.\d+)?"#,
            "cups?", "tablespoons?", "teaspoons?", "tbsp", "tsp",
            "ounces?", "oz", "grams?", "g\\b", "pounds?", "lbs?", "lb",
            "large", "small", "medium", "fresh", "chopped", "minced", "diced",
            "optional", "to taste",
        ]
        for pattern in noise {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return text
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map(String.init)
            .filter { $0.count > 1 }
            .prefix(4)
            .joined(separator: " ")
    }

    private static func matchNumber(in text: String, unitHints: [String]) -> Double? {
        for unit in unitHints {
            let pattern = #"(\d+\s+\d/\d|\d+/\d|\d+(\.\d+)?)\s*"# + NSRegularExpression.escapedPattern(for: unit)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
                  let numberRange = Range(match.range(at: 1), in: text) else { continue }
            return parseFraction(String(text[numberRange]))
        }
        return nil
    }

    private static func parseFraction(_ raw: String) -> Double? {
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
        if cleaned.contains(" ") {
            let parts = cleaned.split(separator: " ")
            guard parts.count == 2,
                  let whole = Double(parts[0]),
                  let frac = parseFraction(String(parts[1])) else { return Double(cleaned) }
            return whole + frac
        }
        if cleaned.contains("/") {
            let parts = cleaned.split(separator: "/")
            guard parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 else { return nil }
            return n / d
        }
        return Double(cleaned)
    }
}
