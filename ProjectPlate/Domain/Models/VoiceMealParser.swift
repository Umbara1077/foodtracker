import Foundation

/// Parses spoken / typed quick-add phrases into meal fields (V1.1 voice logging).
enum VoiceMealParser {
    struct Draft: Equatable, Sendable {
        var title: String?
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
    }

    static func parse(_ transcript: String) -> Draft {
        let normalized = transcript
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return Draft() }

        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var working = normalized

        func take(_ pattern: String) -> Double? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            let range = NSRange(working.startIndex..<working.endIndex, in: working)
            guard let match = regex.firstMatch(in: working, options: [], range: range),
                  match.numberOfRanges >= 2,
                  let numberRange = Range(match.range(at: 1), in: working)
            else { return nil }
            let value = Double(working[numberRange])
            if let full = Range(match.range, in: working) {
                working.replaceSubrange(full, with: " ")
            }
            return value
        }

        calories = take(#"(\d+(?:\.\d+)?)\s*(?:k?cal(?:ories)?|kcals?)\b"#)
            ?? take(#"(?:calories|cals)\s*(?:are|is|of|at|=|:)?\s*(\d+(?:\.\d+)?)"#)
        protein = take(#"(\d+(?:\.\d+)?)\s*(?:g(?:rams?)?\s*)?protein\b"#)
            ?? take(#"protein\s*(?:is|of|at|=|:)?\s*(\d+(?:\.\d+)?)"#)
        carbs = take(#"(\d+(?:\.\d+)?)\s*(?:g(?:rams?)?\s*)?(?:carbs?|carbohydrates?)\b"#)
            ?? take(#"(?:carbs?|carbohydrates?)\s*(?:is|of|at|=|:)?\s*(\d+(?:\.\d+)?)"#)
        fat = take(#"(\d+(?:\.\d+)?)\s*(?:g(?:rams?)?\s*)?fat\b"#)
            ?? take(#"fat\s*(?:is|of|at|=|:)?\s*(\d+(?:\.\d+)?)"#)

        // Bare leading/trailing calorie number if still unset: "oatmeal 350"
        if calories == nil,
           let regex = try? NSRegularExpression(pattern: #"\b(\d{2,4}(?:\.\d+)?)\b"#),
           let match = regex.firstMatch(
            in: working,
            options: [],
            range: NSRange(working.startIndex..<working.endIndex, in: working)
           ),
           let numberRange = Range(match.range(at: 1), in: working)
        {
            calories = Double(working[numberRange])
            if let full = Range(match.range, in: working) {
                working.replaceSubrange(full, with: " ")
            }
        }

        let title = working
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Draft(
            title: title.isEmpty ? nil : title.capitalized,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }
}
