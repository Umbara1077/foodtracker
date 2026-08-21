import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 35 — Custom gateway, reminders, CSV")
struct Phase35FeatureTests {
    @Test("Custom gateway URL requires https in production validation")
    func gatewayURLValidation() {
        switch CustomGatewayStore.validatedURL(from: "https://gateway.example.com", allowHTTPInDebug: false) {
        case .success(let url):
            #expect(url.host == "gateway.example.com")
        case .failure:
            Issue.record("Expected https URL to succeed")
        }
        switch CustomGatewayStore.validatedURL(from: "http://localhost:8787", allowHTTPInDebug: false) {
        case .success:
            Issue.record("Expected http to fail when allowHTTPInDebug is false")
        case .failure(let error):
            #expect(error == .httpsRequired)
        }
        switch CustomGatewayStore.validatedURL(from: "not a url", allowHTTPInDebug: true) {
        case .success:
            Issue.record("Expected invalid URL")
        case .failure(let error):
            #expect(error == .invalidURL)
        }
    }

    @Test("Resolved backend prefers enabled custom gateway")
    func resolvedPrefersCustom() {
        let defaults = UserDefaults(suiteName: "plate.tests.gateway.\(UUID().uuidString)")!
        CustomGatewayStore.setEndpointURLString("https://my-gateway.test", defaults: defaults)
        CustomGatewayStore.setEnabled(true, defaults: defaults)
        let resolved = BackendConfiguration.resolved(installID: "test-install", defaults: defaults)
        #expect(resolved.sourceLabel == "custom")
        #expect(resolved.baseURL?.host == "my-gateway.test")
        #expect(resolved.isCloudEnabled)

        CustomGatewayStore.setEnabled(false, defaults: defaults)
        let managedOrMock = BackendConfiguration.resolved(installID: "test-install", defaults: defaults)
        #expect(managedOrMock.sourceLabel != "custom")
    }

    @Test("CSV export includes header and meal rows")
    func csvExport() async throws {
        let stamp = Date(timeIntervalSince1970: 1_720_000_000)
        let meal = MealRecord(
            id: UUID(),
            eatenAt: stamp,
            mealType: .lunch,
            title: "Bowl, spicy",
            nutrients: NutrientSet(calories: 500, protein: 40, carbs: 45, fat: 12, fiber: 8),
            inputMethod: .quickAdd,
            createdAt: stamp,
            updatedAt: stamp
        )
        let csv = DiaryCSVExporter.csv(from: [meal])
        #expect(csv.contains("eaten_at,meal_type,title"))
        #expect(csv.contains("lunch"))
        #expect(csv.contains("\"Bowl, spicy\""))
        #expect(csv.contains("500"))
        #expect(csv.contains("quickAdd") || csv.contains(MealInputMethod.quickAdd.rawValue))

        let meals = InMemoryMealRepository(meals: [meal])
        let service = DataMaintenanceService(
            mealRepository: meals,
            weightRepository: InMemoryWeightRepository(),
            profileRepository: InMemoryProfileRepository(profile: nil),
            targetRepository: InMemoryTargetRepository(),
            savedMealRepository: InMemorySavedMealRepository()
        )
        let data = try await service.exportCSV()
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("Bowl"))
    }

    @Test("Reminder copy stays supportive")
    func reminderCopy() {
        for meal in ReminderMeal.allCases {
            let body = meal.notificationBody.lowercased()
            #expect(!body.contains("forgot"))
            #expect(!body.contains("missed"))
            #expect(!body.contains("should have"))
        }
        #expect(MealReminderPreference.hour(for: .breakfast) == 8)
        let defaults = UserDefaults(suiteName: "plate.tests.reminders.\(UUID().uuidString)")!
        MealReminderPreference.setHour(9, for: .breakfast, defaults: defaults)
        #expect(MealReminderPreference.hour(for: .breakfast, defaults: defaults) == 9)
    }
}
