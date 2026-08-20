import Foundation
import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            UserProfileEntity.self,
            NutritionTargetEntity.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
