import Foundation

/// Routes meal vision to mock (offline/dev) or managed cloud when configured.
actor MealVisionRouter: MealVisionProvider {
    let id = "vision-router"

    private let mockProvider: any MealVisionProvider
    private let managedProvider: (any MealVisionProvider)?
    private let preferManaged: Bool

    init(
        mockProvider: any MealVisionProvider,
        managedProvider: (any MealVisionProvider)?,
        preferManaged: Bool
    ) {
        self.mockProvider = mockProvider
        self.managedProvider = managedProvider
        self.preferManaged = preferManaged
    }

    func analyze(imageData: Data, context: MealAnalysisContext) async throws -> VisionMealDraft {
        if preferManaged, let managedProvider {
            do {
                return try await managedProvider.analyze(imageData: imageData, context: context)
            } catch MealScanError.quotaExceeded {
                throw MealScanError.quotaExceeded
            } catch MealScanError.unauthorized {
                throw MealScanError.unauthorized
            } catch {
                // Fall back to mock so Simulator / offline still works when cloud fails hard.
                return try await mockProvider.analyze(imageData: imageData, context: context)
            }
        }
        return try await mockProvider.analyze(imageData: imageData, context: context)
    }
}
