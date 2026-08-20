import Foundation

/// Parsed Nutrition Facts values from OCR lines (V1.1 label scan).
struct NutritionLabelDraft: Equatable, Sendable {
    var productName: String?
    var servingGrams: Double?
    var servingLabel: String?
    var caloriesPerServing: Double?
    var proteinPerServing: Double?
    var carbsPerServing: Double?
    var fatPerServing: Double?

    var isUsable: Bool {
        (caloriesPerServing ?? 0) > 0
            || (proteinPerServing ?? 0) > 0
            || (carbsPerServing ?? 0) > 0
            || (fatPerServing ?? 0) > 0
    }

    /// Builds a catalog-compatible food using per-100g nutrients scaled from the serving.
    func asNutritionFood(id: String = UUID().uuidString) -> NutritionFood? {
        guard isUsable else { return nil }
        let grams = max(servingGrams ?? 100, 1)
        let scale = 100.0 / grams
        let per100 = NutrientSet(
            calories: (caloriesPerServing ?? 0) * scale,
            protein: (proteinPerServing ?? 0) * scale,
            carbs: (carbsPerServing ?? 0) * scale,
            fat: (fatPerServing ?? 0) * scale
        )
        let serving: ServingDescriptor?
        if let servingGrams {
            serving = ServingDescriptor(
                label: servingLabel ?? "serving",
                grams: servingGrams
            )
        } else {
            serving = ServingDescriptor(label: "100 g", grams: 100)
        }
        return NutritionFood(
            id: "label.\(id)",
            source: .nutritionLabelOCR,
            name: productName?.isEmpty == false ? productName! : "Label scan",
            brand: nil,
            serving: serving,
            per100g: per100
        )
    }
}

enum NutritionLabelParser {
    static func parse(lines: [String]) -> NutritionLabelDraft {
        parse(text: lines.joined(separator: "\n"))
    }

    static func parse(text: String) -> NutritionLabelDraft {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var draft = NutritionLabelDraft()
        draft.servingGrams = firstMatch(
            in: normalized,
            patterns: [
                #"serving size[^0-9]{0,20}(\d+(?:\.\d+)?)\s*g\b"#,
                #"(\d+(?:\.\d+)?)\s*g\s*(?:serving|serv)\b"#,
            ]
        )
        if let grams = draft.servingGrams {
            draft.servingLabel = "\(Int(grams.rounded())) g serving"
        }

        draft.caloriesPerServing = firstMatch(
            in: normalized,
            patterns: [
                #"calories\s*[:=]?\s*(\d+(?:\.\d+)?)"#,
                #"energy\s*[:=]?\s*(\d+(?:\.\d+)?)\s*k?cal"#,
            ]
        )
        draft.proteinPerServing = firstMatch(
            in: normalized,
            patterns: [
                #"protein\s*[:=]?\s*(\d+(?:\.\d+)?)\s*g?"#,
            ]
        )
        draft.carbsPerServing = firstMatch(
            in: normalized,
            patterns: [
                #"(?:total\s+)?(?:carbohydrate|carbohydrates|carbs)\s*[:=]?\s*(\d+(?:\.\d+)?)\s*g?"#,
            ]
        )
        draft.fatPerServing = firstMatch(
            in: normalized,
            patterns: [
                #"(?:total\s+)?fat\s*[:=]?\s*(\d+(?:\.\d+)?)\s*g?"#,
            ]
        )

        // Prefer a short product-like first line that isn't a facts header.
        if let candidate = lines.first(where: {
            let lower = $0.lowercased()
            return !lower.contains("nutrition")
                && !lower.contains("serving")
                && !lower.contains("calories")
                && $0.count <= 48
        }) {
            draft.productName = candidate
        }
        return draft
    }

    private static func firstMatch(in text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  match.numberOfRanges >= 2,
                  let numberRange = Range(match.range(at: 1), in: text)
            else { continue }
            if let value = Double(text[numberRange]) {
                return value
            }
        }
        return nil
    }
}
