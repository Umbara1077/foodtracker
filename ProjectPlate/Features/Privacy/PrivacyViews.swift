import SwiftUI

struct CloudAIConsentView: View {
    @Environment(\.dismiss) private var dismiss
    var onAccept: () -> Void
    var onDecline: () -> Void

    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space24) {
                    Text(CloudAIConsentCopy.title)
                        .font(Typography.screenTitle)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text(CloudAIConsentCopy.body)
                        .font(Typography.body)
                        .foregroundStyle(Color.textSecondary)

                    Button("Privacy details") {
                        showDetails = true
                    }
                    .font(Typography.supporting.weight(.semibold))

                    PrimaryButton(title: "Continue") {
                        onAccept()
                        dismiss()
                    }

                    SecondaryButton(title: "Not now") {
                        onDecline()
                        dismiss()
                    }

                    Text("Consent version \(PrivacyConstants.cloudAIConsentVersion)")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space24)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDetails) {
                PrivacyPolicyView()
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space16) {
                    Text("Privacy Policy")
                        .font(Typography.screenTitle)
                    Text("Working draft for Project Plate (working title). Replace example.com URLs before App Store submission.")
                        .font(Typography.supporting)
                        .foregroundStyle(Color.textSecondary)

                    policySection(
                        "What we store on your iPhone",
                        "Meals, weight entries, targets, preferences, and optional meal photo thumbnails stay on device in SwiftData unless you enable Apple Health sync or cloud AI scans."
                    )
                    policySection(
                        "Cloud AI scans",
                        "When you consent, a compressed meal photo (location metadata stripped) is sent to our managed gateway for food recognition. We do not permanently store standard scan photos. Structured food/portion drafts may be returned to your device."
                    )
                    policySection(
                        "Apple Health",
                        "If you enable Health sync, nutrition and weight you log can be written to Apple Health, and weight can be read for Progress. You can revoke access in iOS Settings."
                    )
                    policySection(
                        "Subscriptions",
                        "Purchases are processed by Apple. We receive entitlement status, not your full payment card details."
                    )
                    policySection(
                        "Your controls",
                        "Export or delete local data from Settings → Privacy. Declining cloud AI leaves manual, barcode, and quick-add logging available."
                    )

                    Link("Open web privacy policy", destination: PrivacyConstants.privacyPolicyURL)
                        .font(Typography.supporting.weight(.semibold))
                }
                .padding(Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space24)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Privacy policy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space8) {
            Text(title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Color.textPrimary)
            Text(body)
                .font(Typography.body)
                .foregroundStyle(Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TermsOfUseView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space16) {
                    Text("Terms of Use")
                        .font(Typography.screenTitle)
                    Text("Nutrition estimates are for informational tracking and may be inaccurate. Project Plate does not provide medical advice. Replace this draft before App Store review.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textSecondary)
                    Link("Open web terms", destination: PrivacyConstants.termsURL)
                        .font(Typography.supporting.weight(.semibold))
                }
                .padding(Spacing.screenHorizontal)
                .padding(.vertical, Spacing.space24)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Terms")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("Consent") {
    CloudAIConsentView(onAccept: {}, onDecline: {})
}
