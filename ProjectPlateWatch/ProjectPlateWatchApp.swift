import SwiftUI

@main
struct ProjectPlateWatchApp: App {
    var body: some Scene {
        WindowGroup {
            TodayWatchView()
        }
    }
}

struct TodayWatchView: View {
    @State private var content = WatchGlancePresenter.content(from: nil)
    @State private var tick = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Plate")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(content.headline)
                    .font(.headline)
                Text(content.caloriesValue)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(content.caloriesCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Divider()
                Text(content.proteinLine)
                    .font(.caption.weight(.semibold))
                Text(content.mealsLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if content.emptyState {
                    Text("Glance updates after you open Today on iPhone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .onAppear(perform: reload)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            tick = date
            reload()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(content.headline), \(content.caloriesValue) calories. \(content.proteinLine). \(content.mealsLine)")
    }

    private func reload() {
        content = WatchGlancePresenter.content(from: WidgetSnapshotStore.load())
    }
}

#Preview {
    TodayWatchView()
}
