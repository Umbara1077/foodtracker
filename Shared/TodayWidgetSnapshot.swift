import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Shared App Group payload for the Home Screen widget (V1.1).
struct TodayWidgetSnapshot: Codable, Equatable, Sendable {
    var updatedAt: Date
    var remainingCalories: Int
    var eatenCalories: Int
    var targetCalories: Int
    var proteinGrams: Int
    var proteinTargetGrams: Int
    var mealCount: Int

    static let placeholder = TodayWidgetSnapshot(
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        remainingCalories: 850,
        eatenCalories: 1330,
        targetCalories: 2180,
        proteinGrams: 92,
        proteinTargetGrams: 136,
        mealCount: 2
    )

    var isOverTarget: Bool { remainingCalories < 0 }

    var headline: String {
        isOverTarget ? "Over target" : "Remaining"
    }

    var remainingDisplay: String {
        "\(abs(remainingCalories))"
    }
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.projectplate.app"
    static let storageKey = "plate.widget.todaySnapshot"

    static func save(_ snapshot: TodayWidgetSnapshot, defaults: UserDefaults? = nil) {
        let store = defaults ?? UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: storageKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func load(defaults: UserDefaults? = nil) -> TodayWidgetSnapshot? {
        let store = defaults ?? UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = store.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(TodayWidgetSnapshot.self, from: data)
    }
}
