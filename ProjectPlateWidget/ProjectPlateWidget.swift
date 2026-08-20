import SwiftUI
import WidgetKit

struct TodayCaloriesProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayCaloriesEntry {
        TodayCaloriesEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayCaloriesEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        completion(TodayCaloriesEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayCaloriesEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        let entry = TodayCaloriesEntry(date: .now, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayCaloriesEntry: TimelineEntry {
    let date: Date
    let snapshot: TodayWidgetSnapshot
}

struct TodayCaloriesWidgetView: View {
    var entry: TodayCaloriesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Project Plate")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(entry.snapshot.headline)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(entry.snapshot.remainingDisplay)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
            Text("cal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Project Plate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.snapshot.headline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(entry.snapshot.remainingDisplay)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("cal")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                labeled("Eaten", "\(entry.snapshot.eatenCalories)")
                labeled("Protein", "\(entry.snapshot.proteinGrams)g")
                labeled("Meals", "\(entry.snapshot.mealCount)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct TodayCaloriesWidget: Widget {
    let kind = "TodayCaloriesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayCaloriesProvider()) { entry in
            TodayCaloriesWidgetView(entry: entry)
        }
        .configurationDisplayName("Today’s calories")
        .description("Remaining calories and a quick protein check.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ProjectPlateWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayCaloriesWidget()
        TodayLiveActivityWidget()
    }
}
