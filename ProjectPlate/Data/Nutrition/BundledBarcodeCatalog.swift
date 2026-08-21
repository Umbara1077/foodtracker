import Foundation

/// Offline barcode → nutrition map for Simulator / no-network. Never invents values for unknown codes.
enum BundledBarcodeCatalog {
    struct Entry: Sendable {
        var barcode: String
        var food: NutritionFood
    }

    static let entries: [Entry] = [
        Entry(
            barcode: "012345678905",
            food: NutritionFood(
                id: "barcode.greek_yogurt",
                source: .usdaShapedFixture,
                name: "Greek yogurt, plain, nonfat",
                brand: "Fixture Farms",
                serving: ServingDescriptor(label: "container", grams: 170),
                per100g: NutrientSet(calories: 59, protein: 10, carbs: 3.6, fat: 0.4)
            )
        ),
        Entry(
            barcode: "0012000012345",
            food: NutritionFood(
                id: "barcode.granola",
                source: .usdaShapedFixture,
                name: "Granola",
                brand: "Fixture Crunch",
                serving: ServingDescriptor(label: "1/2 cup", grams: 61),
                per100g: NutrientSet(calories: 471, protein: 10, carbs: 64, fat: 20)
            )
        ),
        Entry(
            barcode: "0049000002891",
            food: NutritionFood(
                id: "barcode.oatmeal",
                source: .usdaShapedFixture,
                name: "Oatmeal, cooked",
                brand: nil,
                serving: ServingDescriptor(label: "cup", grams: 234),
                per100g: NutrientSet(calories: 71, protein: 2.5, carbs: 12, fat: 1.5)
            )
        ),
        Entry(
            barcode: "0737628064502",
            food: NutritionFood(
                id: "barcode.protein_bar",
                source: .openFoodFacts,
                name: "Protein bar, chocolate",
                brand: "Fixture Fuel",
                serving: ServingDescriptor(label: "bar", grams: 60),
                per100g: NutrientSet(calories: 380, protein: 25, carbs: 35, fat: 12)
            )
        ),
        Entry(
            barcode: "5000112588138",
            food: NutritionFood(
                id: "barcode.almonds",
                source: .usdaShapedFixture,
                name: "Almonds",
                brand: nil,
                serving: ServingDescriptor(label: "oz", grams: 28),
                per100g: NutrientSet(calories: 579, protein: 21, carbs: 22, fat: 50)
            )
        ),
    ]

    static func food(forBarcode raw: String) -> NutritionFood? {
        let code = BarcodeNormalizer.normalize(raw)
        return entries.first(where: { BarcodeNormalizer.normalize($0.barcode) == code })?.food
    }
}

enum BarcodeNormalizer {
    /// Strip spaces/dashes; keep digits. UPC-E expansion is out of scope for V1 fixtures.
    static func normalize(_ raw: String) -> String {
        raw.filter(\.isNumber)
    }

    static func isPlausible(_ raw: String) -> Bool {
        let code = normalize(raw)
        return [8, 12, 13, 14].contains(code.count)
    }
}
