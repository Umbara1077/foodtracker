import Foundation
import Testing
import UIKit
@testable import ProjectPlate

@Suite("Phase 34 — App Store compliance")
struct AppStoreComplianceTests {
    @Test("Cloud AI consent persists accept and decline per version")
    func consentStore() {
        let defaults = UserDefaults(suiteName: "plate.tests.consent.\(UUID().uuidString)")!
        #expect(CloudAIConsentStore.needsPrompt(defaults: defaults))
        #expect(!CloudAIConsentStore.allowsCloudUpload(defaults: defaults))

        CloudAIConsentStore.set(.declined, defaults: defaults)
        #expect(!CloudAIConsentStore.needsPrompt(defaults: defaults))
        #expect(!CloudAIConsentStore.allowsCloudUpload(defaults: defaults))
        #expect(CloudAIConsentStore.statusLabel(defaults: defaults).contains("Declined"))

        CloudAIConsentStore.set(.accepted, defaults: defaults)
        #expect(CloudAIConsentStore.allowsCloudUpload(defaults: defaults))
        #expect(CloudAIConsentStore.statusLabel(defaults: defaults).contains("Accepted"))

        CloudAIConsentStore.clear(defaults: defaults)
        #expect(CloudAIConsentStore.needsPrompt(defaults: defaults))
    }

    @Test("Vision router skips cloud when consent declined")
    func routerRespectsConsent() async throws {
        actor Flag {
            var called = false
            func mark() { called = true }
            func value() -> Bool { called }
        }
        struct SpyManaged: MealVisionProvider {
            let id = "spy"
            let flag: Flag
            func analyze(imageData: Data, context: MealAnalysisContext) async throws -> VisionMealDraft {
                await flag.mark()
                return VisionMealDraft(mealName: "Spy", items: [], overallConfidence: 1)
            }
        }
        let flag = Flag()
        let router = MealVisionRouter(
            mockProvider: MockMealVisionProvider(fixture: .chickenRiceBowl, delayNanoseconds: 0),
            managedProvider: SpyManaged(flag: flag),
            preferManaged: true,
            cloudUploadAllowed: { false }
        )
        _ = try await router.analyze(imageData: Data([0xFF, 0xD8, 0xFF]), context: .default)
        #expect(await flag.value() == false)
    }

    @Test("Image preprocessor re-encodes instead of truncating")
    func imagePreprocessor() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            Issue.record("Could not make JPEG")
            return
        }
        let normalized = ImagePreprocessor.normalizeForUpload(jpeg, maxBytes: 2_500_000)
        #expect(!normalized.isEmpty)
        #expect(UIImage(data: normalized) != nil)
        // Undecodable stubs become a privacy-safe placeholder JPEG (not empty, not raw passthrough).
        let stub = ImagePreprocessor.normalizeForUpload(Data([0x00, 0x01, 0x02]))
        #expect(!stub.isEmpty)
        #expect(UIImage(data: stub) != nil)
        #expect(ImagePreprocessor.normalizeForUpload(Data()).isEmpty)
    }

    @Test("Delete uploads tombstones when iCloud sync is enabled")
    func deleteUploadsTombstones() async throws {
        let defaults = UserDefaults(suiteName: "plate.tests.delete.\(UUID().uuidString)")!
        CloudSyncPreference.setEnabled(true, defaults: defaults)

        let meal = MealRecord(
            mealType: .lunch,
            title: "Tombstone me",
            nutrients: NutrientSet(calories: 100, protein: 1, carbs: 1, fat: 1),
            inputMethod: .quickAdd
        )
        let meals = InMemoryMealRepository(meals: [meal])
        let sync = InMemorySyncService()
        let coordinator = DiarySyncCoordinator(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: nil),
            targetRepository: InMemoryTargetRepository(),
            savedMealRepository: InMemorySavedMealRepository(),
            syncService: sync,
            defaults: defaults
        )
        let service = DataMaintenanceService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: UserProfile.blank),
            targetRepository: InMemoryTargetRepository(),
            savedMealRepository: InMemorySavedMealRepository(),
            diarySync: coordinator
        )
        try await service.deleteAllLocalData(purgeCloudCopies: true)
        let uploaded = await sync.storedRecords()
        #expect(uploaded.contains(where: { $0.id == meal.id && $0.deleted }))
        let remaining = try await meals.meals(on: .now, calendar: .current)
        #expect(remaining.isEmpty)
    }

    @Test("Support URL helper accepts mailto and https overrides")
    func supportURLOverride() {
        let mail = PrivacyConstants.url(
            fromRaw: "mailto:help@example.org",
            fallback: URL(string: "mailto:support@projectplate.app")!
        )
        #expect(mail.scheme == "mailto")
        let https = PrivacyConstants.url(
            fromRaw: "https://projectplate.app/support",
            fallback: URL(string: "mailto:support@projectplate.app")!
        )
        #expect(https.host == "projectplate.app")
    }
}
