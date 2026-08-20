import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space24) {
                    MetricCard(
                        title: "Calories remaining",
                        value: "—",
                        subtitle: "Finish onboarding to set a target"
                    )

                    VStack(alignment: .leading, spacing: Spacing.space12) {
                        MacroProgressView(label: "Protein", current: 0, goal: 150, unit: "g", tint: .macroProtein)
                        MacroProgressView(label: "Carbs", current: 0, goal: 200, unit: "g", tint: .macroCarbs)
                        MacroProgressView(label: "Fat", current: 0, goal: 65, unit: "g", tint: .macroFat)
                    }
                    .padding(Spacing.cardPaddingCompact)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                    emptyState
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space24)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Today")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.space16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)
            Text("Your first meal takes one photo.")
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("Scan, barcode, and manual logging arrive in later phases. The camera button below is ready.")
                .font(Typography.supporting)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.space32)
        .background(Color.surfaceSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TodayView()
}
