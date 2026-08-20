import Foundation
import SwiftData

@Model
final class SavedMealEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var fingerprint: String
    var title: String
    var mealTypeRaw: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var useCount: Int
    var lastUsedAt: Date
    var createdAt: Date

    init(from template: SavedMealTemplate) {
        self.id = template.id
        self.fingerprint = template.fingerprint
        self.title = template.title
        self.mealTypeRaw = template.mealType.rawValue
        self.calories = template.nutrients.calories
        self.protein = template.nutrients.protein
        self.carbs = template.nutrients.carbs
        self.fat = template.nutrients.fat
        self.useCount = template.useCount
        self.lastUsedAt = template.lastUsedAt
        self.createdAt = template.createdAt
    }

    func apply(_ template: SavedMealTemplate) {
        id = template.id
        fingerprint = template.fingerprint
        title = template.title
        mealTypeRaw = template.mealType.rawValue
        calories = template.nutrients.calories
        protein = template.nutrients.protein
        carbs = template.nutrients.carbs
        fat = template.nutrients.fat
        useCount = template.useCount
        lastUsedAt = template.lastUsedAt
        createdAt = template.createdAt
    }

    func asDomain() -> SavedMealTemplate {
        SavedMealTemplate(
            id: id,
            fingerprint: fingerprint,
            title: title,
            mealType: MealType(rawValue: mealTypeRaw) ?? .snack,
            nutrients: NutrientSet(calories: calories, protein: protein, carbs: carbs, fat: fat),
            useCount: useCount,
            lastUsedAt: lastUsedAt,
            createdAt: createdAt
        )
    }
}
