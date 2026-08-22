import SwiftUI

struct AcknowledgmentsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space16) {
                Text("Acknowledgments")
                    .font(Typography.screenTitle)

                Text("Project Plate uses Apple frameworks and public nutrition data sources. Estimates are informational and may be inaccurate.")
                    .font(Typography.body)
                    .foregroundStyle(Color.textSecondary)

                section("Apple", [
                    "SwiftUI, SwiftData, StoreKit 2, HealthKit, CloudKit, Vision, Speech, WidgetKit, ActivityKit, WatchConnectivity",
                ])
                section("Nutrition data", [
                    "Bundled USDA-shaped reference catalog for offline search",
                    "Open Food Facts for barcode lookups when network is available",
                ])
                section("Privacy", [
                    "Meal photos for cloud analysis are re-encoded without EXIF/GPS",
                    "Custom gateway tokens are stored in the iOS Keychain",
                    "No third-party advertising or tracking SDKs in this build",
                ])
                section("Design", [
                    "SF Symbols for interface icons",
                    "Semantic color assets with light and dark variants",
                ])
            }
            .padding(Spacing.screenHorizontal)
            .padding(.vertical, Spacing.space24)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space8) {
            Text(title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)
            ForEach(lines, id: \.self) { line in
                Text("• \(line)")
                    .font(Typography.supporting)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { AcknowledgmentsView() }
}
