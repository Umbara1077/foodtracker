import ActivityKit
import SwiftUI
import WidgetKit

struct TodayLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayCaloriesAttributes.self) { context in
            lockScreen(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Project Plate")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(context.state.headline)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.remainingDisplay)
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text("cal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.eatenCalories) eaten", systemImage: "fork.knife")
                        Spacer()
                        Text("P \(context.state.proteinGrams)g")
                        Text("·")
                        Text("\(context.state.mealCount) meals")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.mint)
            } compactTrailing: {
                Text(context.state.remainingDisplay)
                    .font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                Text(context.state.remainingDisplay)
                    .font(.caption2.weight(.bold).monospacedDigit())
            }
        }
    }

    @ViewBuilder
    private func lockScreen(context: ActivityViewContext<TodayCaloriesAttributes>) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Project Plate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(context.state.headline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(context.state.remainingDisplay)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("cal")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(context.state.eatenCalories) / \(context.state.targetCalories)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text("Protein \(context.state.proteinGrams)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(context.state.mealCount) meals")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color(.systemBackground).opacity(0.92))
        .activitySystemActionForegroundColor(.primary)
    }
}
