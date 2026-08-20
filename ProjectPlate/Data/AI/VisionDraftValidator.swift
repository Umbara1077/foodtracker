import Foundation

enum VisionDraftValidator {
    static func validate(_ draft: VisionMealDraft) throws -> VisionMealDraft {
        guard draft.schemaVersion == 1 else {
            throw MealScanError.invalidStructuredResponse
        }
        guard (0...20).contains(draft.items.count) else {
            throw MealScanError.invalidStructuredResponse
        }

        var cleaned: [VisionFoodItem] = []
        cleaned.reserveCapacity(draft.items.count)

        for item in draft.items {
            let name = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let query = item.canonicalQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !query.isEmpty else {
                throw MealScanError.invalidStructuredResponse
            }
            guard item.estimatedGrams > 0,
                  item.gramRangeLow > 0,
                  item.gramRangeHigh > 0,
                  item.gramRangeLow <= item.estimatedGrams,
                  item.estimatedGrams <= item.gramRangeHigh,
                  item.estimatedGrams <= 5000
            else {
                throw MealScanError.invalidStructuredResponse
            }

            cleaned.append(
                VisionFoodItem(
                    id: item.id,
                    displayName: String(name.prefix(120)),
                    canonicalQuery: String(query.prefix(120)),
                    estimatedGrams: item.estimatedGrams,
                    gramRangeLow: item.gramRangeLow,
                    gramRangeHigh: item.gramRangeHigh,
                    preparation: item.preparation.map { String($0.prefix(60)) },
                    brandOrRestaurant: item.brandOrRestaurant.map { String($0.prefix(80)) },
                    visibleAdditions: Array(item.visibleAdditions.prefix(12)),
                    confidence: clamp01(item.confidence)
                )
            )
        }

        return VisionMealDraft(
            schemaVersion: 1,
            mealName: String(draft.mealName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
            items: cleaned,
            overallConfidence: clamp01(draft.overallConfidence),
            clarifyingQuestion: draft.clarifyingQuestion.map { String($0.prefix(200)) },
            uncertaintyNotes: Array(draft.uncertaintyNotes.prefix(8))
        )
    }

    private static func clamp01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
