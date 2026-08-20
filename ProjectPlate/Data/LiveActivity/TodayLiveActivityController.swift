import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Starts, updates, and ends the “Today’s calories” Live Activity from diary snapshots.
@MainActor
enum TodayLiveActivityController {
    static func sync(with snapshot: TodayWidgetSnapshot, calendar: Calendar = .current) {
        #if canImport(ActivityKit)
        guard TodayLiveActivityPolicy.isEnabled() else {
            Task { await endAll() }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard TodayLiveActivityPolicy.shouldPresent(snapshot: snapshot) else {
            Task { await endAll() }
            return
        }

        let dayStart = calendar.startOfDay(for: snapshot.updatedAt)
        let state = TodayCaloriesAttributes.ContentState.from(snapshot)
        let stale = TodayLiveActivityPolicy.endOfDay(for: snapshot.updatedAt, calendar: calendar)
        let content = ActivityContent(state: state, staleDate: stale)

        if let existing = Activity<TodayCaloriesAttributes>.activities.first {
            if !calendar.isDate(existing.attributes.dayStart, inSameDayAs: dayStart) {
                Task {
                    await existing.end(nil, dismissalPolicy: .immediate)
                    _ = try? request(dayStart: dayStart, content: content)
                }
            } else {
                Task { await existing.update(content) }
            }
            return
        }

        _ = try? request(dayStart: dayStart, content: content)
        #endif
    }

    static func endAll() async {
        #if canImport(ActivityKit)
        for activity in Activity<TodayCaloriesAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        #endif
    }

    #if canImport(ActivityKit)
    private static func request(
        dayStart: Date,
        content: ActivityContent<TodayCaloriesAttributes.ContentState>
    ) throws -> Activity<TodayCaloriesAttributes> {
        try Activity.request(
            attributes: TodayCaloriesAttributes(dayStart: dayStart),
            content: content,
            pushType: nil
        )
    }
    #endif
}
