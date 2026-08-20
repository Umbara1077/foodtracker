import Foundation
import SwiftData

@Model
final class MealEntity {
    @Attribute(.unique) var id: UUID
    var eatenAt: Date
    var mealTypeRaw: String
    var title: String
    var notes: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var inputMethodRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(from meal: MealRecord) {
        self.id = meal.id
        self.eatenAt = meal.eatenAt
        self.mealTypeRaw = meal.mealType.rawValue
        self.title = meal.title
        self.notes = meal.notes
        self.calories = meal.nutrients.calories
        self.protein = meal.nutrients.protein
        self.carbs = meal.nutrients.carbs
        self.fat = meal.nutrients.fat
        self.inputMethodRaw = meal.inputMethod.rawValue
        self.createdAt = meal.createdAt
        self.updatedAt = meal.updatedAt
    }

    func apply(_ meal: MealRecord) {
        id = meal.id
        eatenAt = meal.eatenAt
        mealTypeRaw = meal.mealType.rawValue
        title = meal.title
        notes = meal.notes
        calories = meal.nutrients.calories
        protein = meal.nutrients.protein
        carbs = meal.nutrients.carbs
        fat = meal.nutrients.fat
        inputMethodRaw = meal.inputMethod.rawValue
        createdAt = meal.createdAt
        updatedAt = meal.updatedAt
    }

    func asDomain() -> MealRecord {
        MealRecord(
            id: id,
            eatenAt: eatenAt,
            mealType: MealType(rawValue: mealTypeRaw) ?? .snack,
            title: title,
            notes: notes,
            nutrients: NutrientSet(calories: calories, protein: protein, carbs: carbs, fat: fat),
            inputMethod: MealInputMethod(rawValue: inputMethodRaw) ?? .quickAdd,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
