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

                    Text("This summary matches how Project Plate handles data on your device. When a web policy URL is configured, that page is the canonical public version.")
                        .font(Typography.supporting)
                        .foregroundStyle(Color.textSecondary)

                    policySection(
                        "What we store on your iPhone",
                        "Meals, weight entries, targets, and preferences stay on device in SwiftData unless you enable Apple Health sync, iCloud diary sync, or cloud AI scans. Meal photos used for a scan are processed in memory for analysis and are not saved into your diary."
                    )
                    policySection(
                        "Cloud AI scans",
                        "When you accept cloud analysis, a re-encoded JPEG meal photo (without camera EXIF/GPS metadata) is sent to our managed gateway, which may use a third-party model provider to recognize food. We do not permanently store standard scan photos on our servers. Structured food and portion drafts may be returned to your device. Declining keeps photo scan on-device and never uploads the image."
                    )
                    policySection(
                        "iCloud sync",
                        "If you enable iCloud diary sync, meal and weight records (not meal photos) sync through your private iCloud database so other devices signed into the same Apple Account can restore them. Deleting your data in Settings also marks synced copies deleted when iCloud sync is on. You can turn sync off anytime in Settings."
                    )
                    policySection(
                        "Recipe URL import",
                        "If you paste a recipe link, Project Plate downloads that page on your device to read ingredients and estimate nutrition. We do not permanently store the page HTML on our servers."
                    )
                    policySection(
                        "Apple Health",
                        "If you enable Health sync, nutrition and weight you log can be written to Apple Health, and weight can be read for Progress. You can revoke access in iOS Settings."
                    )
                    policySection(
                        "Subscriptions",
                        "Purchases are processed by Apple. We receive entitlement status, not your full payment card details. See Terms of Use for auto-renewal details."
                    )
                    policySection(
                        "Your controls",
                        "Export or delete data from Settings → Privacy. Manage cloud AI consent, Health, and iCloud sync in Settings. Declining cloud AI leaves manual, barcode, quick-add, and on-device scan available."
                    )

                    if PrivacyConstants.usesPlaceholderLegalURLs {
                        Text("A public web privacy policy URL is not configured yet. Set PLATE_PRIVACY_POLICY_URL before App Store submission.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Link("Open web privacy policy", destination: PrivacyConstants.privacyPolicyURL)
                            .font(Typography.supporting.weight(.semibold))
                    }
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

                    Text("By using Project Plate you agree to these terms. Nutrition and calorie estimates are for informational tracking only and may be inaccurate. Project Plate does not provide medical advice, diagnosis, or treatment.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textSecondary)

                    Text("License")
                        .font(Typography.sectionHeading)
                    Text("We grant you a personal, non-exclusive, non-transferable license to use the app on Apple devices you own or control, as permitted by the App Store terms.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textSecondary)

                    Text("Subscriptions")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Color.textPrimary)

                    Text(
                        """
                        Project Plate Pro is an auto-renewable subscription sold through Apple. \
                        \(SubscriptionLegalCopy.autoRenewSummary)

                        Plans: Pro Monthly and Pro Annual. Prices appear in the App Store and on the purchase screen in your local currency.

                        \(SubscriptionLegalCopy.freeKeepsHistory)
                        """
                    )
                    .font(Typography.body)
                    .foregroundStyle(Color.textSecondary)

                    Text("Acceptable use")
                        .font(Typography.sectionHeading)
                    Text("Do not misuse scan or sync features, attempt to disrupt services, or use the app for unlawful purposes.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textSecondary)

                    Text("Limitation of liability")
                        .font(Typography.sectionHeading)
                    Text("To the fullest extent permitted by law, Project Plate and its contributors are not liable for decisions you make based on estimates in the app.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textSecondary)

                    Text("Contact")
                        .font(Typography.sectionHeading)
                    Text("Questions about these terms: use Support in Settings → About.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textSecondary)

                    if PrivacyConstants.usesPlaceholderLegalURLs {
                        Text("A public web Terms URL is not configured yet. Set PLATE_TERMS_URL before App Store submission.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Link("Open web terms", destination: PrivacyConstants.termsURL)
                            .font(Typography.supporting.weight(.semibold))
                    }
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
