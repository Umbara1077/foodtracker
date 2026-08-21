import Foundation

/// Routes meal vision to mock (offline/dev) or managed/custom cloud when configured **and** cloud AI consent is accepted.
actor MealVisionRouter: MealVisionProvider {
    let id = "vision-router"

    private let mockProvider: any MealVisionProvider
    private let managedProvider: (any MealVisionProvider)?
    private let preferManaged: Bool
    private let cloudUploadAllowed: @Sendable () -> Bool
    private let cloudConfigured: @Sendable () -> Bool

    init(
        mockProvider: any MealVisionProvider,
        managedProvider: (any MealVisionProvider)?,
        preferManaged: Bool,
        cloudUploadAllowed: @escaping @Sendable () -> Bool = { CloudAIConsentStore.allowsCloudUpload() },
        cloudConfigured: @escaping @Sendable () -> Bool = { BackendConfiguration.resolved().isCloudEnabled }
    ) {
        self.mockProvider = mockProvider
        self.managedProvider = managedProvider
        self.preferManaged = preferManaged
        self.cloudUploadAllowed = cloudUploadAllowed
        self.cloudConfigured = cloudConfigured
    }

    func analyze(imageData: Data, context: MealAnalysisContext) async throws -> VisionMealDraft {
        if preferManaged, cloudConfigured(), cloudUploadAllowed(), let managedProvider {
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
