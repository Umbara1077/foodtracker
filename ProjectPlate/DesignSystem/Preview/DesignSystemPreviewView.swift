import SwiftUI

#if DEBUG
struct DesignSystemPreviewView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space24) {
                    section("Buttons") {
                        PrimaryButton(title: "Primary", action: {})
                        SecondaryButton(title: "Secondary", action: {})
                    }
                    section("Metric") {
                        MetricCard(
                            title: "Calories remaining",
                            value: "1,042",
                            subtitle: "1,138 eaten · 2,180 goal"
                        )
                    }
                    section("Macros") {
                        MacroProgressView(label: "Protein", current: 82, goal: 164, unit: "g", tint: .macroProtein)
                        MacroProgressView(label: "Carbs", current: 109, goal: 245, unit: "g", tint: .macroCarbs)
                        MacroProgressView(label: "Fat", current: 41, goal: 73, unit: "g", tint: .macroFat)
                        MacroProgressView(label: "Fiber", current: 18, goal: 28, unit: "g", tint: .macroFiber)
                        Text("Error sample")
                            .font(Typography.caption)
                            .foregroundStyle(Color.statusError)
                    }
                    section("Confidence") {
                        HStack {
                            ConfidencePill(confidence: .high)
                            ConfidencePill(confidence: .medium)
                            ConfidencePill(confidence: .low)
                        }
                    }
                }
                .padding(Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space24)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Design System")
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space12) {
            Text(title).font(Typography.sectionHeading).foregroundStyle(Color.textPrimary)
            content()
        }
    }
}

#Preview("Design system") {
    DesignSystemPreviewView()
}

#Preview("Design system dark") {
    DesignSystemPreviewView()
        .preferredColorScheme(.dark)
}
#endif
