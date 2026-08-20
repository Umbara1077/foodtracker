import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var showDesignSystem = false
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var exportDocument: ExportDocument?
    @State private var targetSummary: String = "Loading…"
    @State private var healthEnabled = false
    @State private var healthStatusText = "Checking…"
    @State private var healthMessage: String?
    @State private var isWorkingHealth = false
    @State private var subscriptionLabel = "Loading…"
    @State private var entitlementIsPro = false
    @State private var freeScansRemaining: Int?
    @State private var subscriptionMessage: String?
    @AppStorage("plate.save_meal_photos") private var saveMealPhotos = true
    @State private var consentVersionLabel = "Not accepted"
    @State private var privacyMessage: String?
    @State private var isPrivacyWorking = false

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    Text("Goal & targets are set during onboarding.")
                        .foregroundStyle(Color.textSecondary)
                    Text(targetSummary)
                        .font(Typography.supporting)
                        .foregroundStyle(Color.textPrimary)
                }
                Section("Subscription") {
                    LabeledContent("Plan", value: subscriptionLabel)
                    if let freeScansRemaining {
                        LabeledContent(
                            "Free scans left today",
                            value: entitlementIsPro ? "Unlimited" : "\(freeScansRemaining) / 3"
                        )
                    }
                    Button("See Project Plate Pro") {
                        environment.analytics.track(.paywallViewed)
                        showPaywall = true
                    }
                    Button("Restore purchases") {
                        Task { await restorePurchases() }
                    }
                    if let subscriptionMessage {
                        Text(subscriptionMessage)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("History and manual logging stay available on Free.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Apple Health") {
                    Toggle("Sync meals & weight", isOn: $healthEnabled)
                        .disabled(!environment.healthSync.isDataAvailable || isWorkingHealth)
                        .onChange(of: healthEnabled) { _, enabled in
                            Task { await setHealthEnabled(enabled) }
                        }
                    Text(healthStatusText)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    if environment.healthSync.isDataAvailable {
                        Button("Import recent Health weights") {
                            Task { await importWeights() }
                        }
                        .disabled(!healthEnabled || isWorkingHealth)
                    } else {
                        Text("Health data isn’t available on this device. The diary still works locally.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    if let healthMessage {
                        Text(healthMessage)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Section("Cloud AI") {
                    LabeledContent(
                        "Mode",
                        value: environment.backendConfiguration.isCloudEnabled ? "Managed gateway" : "On-device mock"
                    )
                    if let remaining = environment.scanQuota.remaining,
                       let limit = environment.scanQuota.dailyLimit {
                        LabeledContent("Cloud quota", value: "\(remaining) / \(limit)")
                    } else if environment.backendConfiguration.isCloudEnabled {
                        Text("Cloud quota updates after the first cloud scan.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Set PLATE_API_BASE_URL to use the managed backend. Photos are never stored permanently.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Section("Privacy") {
                    Toggle("Save meal photos on device", isOn: $saveMealPhotos)
                        .accessibilityHint("Photos stay on this iPhone when enabled")

                    LabeledContent("AI consent", value: consentVersionLabel)

                    NavigationLink("Privacy policy") {
                        PrivacyPolicyView()
                    }
                    NavigationLink("Terms of use") {
                        TermsOfUseView()
                    }

                    Button("Export my data") {
                        Task { await exportData() }
                    }
                    .disabled(isPrivacyWorking)

                    Button("Delete my data", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(isPrivacyWorking)

                    if let privacyMessage {
                        Text(privacyMessage)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Section("TestFlight") {
                    NavigationLink {
                        TestFlightToolsView()
                    } label: {
                        Label("Beta tools", systemImage: "airplane")
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: "1.2.2")
                    Text("Nutrition estimates are for informational tracking and may be inaccurate. This app does not provide medical advice.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    Text("Working title — brand clearance required before public launch.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                #if DEBUG
                Section("Debug") {
                    Button("Design system gallery") {
                        showDesignSystem = true
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView {
                    Task { await refreshSubscription() }
                }
            }
            .fileExporter(
                isPresented: Binding(
                    get: { exportDocument != nil },
                    set: { if !$0 { exportDocument = nil } }
                ),
                document: exportDocument,
                contentType: .json,
                defaultFilename: "project-plate-export"
            ) { result in
                switch result {
                case .success:
                    privacyMessage = "Export saved."
                    environment.analytics.track(.dataExported)
                case .failure:
                    privacyMessage = "Export cancelled or failed."
                }
            }
            .confirmationDialog(
                "Delete all local data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    Task { await deleteData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes meals, weight entries, and resets onboarding on this iPhone. It cannot be undone.")
            }
            #if DEBUG
            .sheet(isPresented: $showDesignSystem) {
                DesignSystemPreviewView()
            }
            #endif
            .task {
                await refresh()
            }
        }
    }

    private func refresh() async {
        if let target = try? await environment.targetRepository.currentTarget(on: .now) {
            targetSummary = "\(target.calories) cal · P \(target.proteinGrams)g · C \(target.carbGrams)g · F \(target.fatGrams)g"
        } else {
            targetSummary = "No target saved yet."
        }
        if let profile = try? await environment.profileRepository.loadProfile() {
            healthEnabled = profile.healthKitEnabled
            if let version = profile.cloudAIConsentVersion {
                consentVersionLabel = version == PrivacyConstants.cloudAIConsentVersion
                    ? "Accepted (\(version))"
                    : "Out of date (\(version))"
            } else {
                consentVersionLabel = "Not accepted"
            }
        }
        healthStatusText = statusLabel(environment.healthSync.authorizationStatus())
        await refreshSubscription()
    }

    private func refreshSubscription() async {
        let entitlement = await environment.subscriptions.currentEntitlement()
        entitlementIsPro = entitlement.isPro
        switch entitlement {
        case .free:
            subscriptionLabel = "Free"
        case .pro(let expiration):
            if let expiration {
                subscriptionLabel = "Pro · renews \(expiration.formatted(date: .abbreviated, time: .omitted))"
            } else {
                subscriptionLabel = "Pro"
            }
        }
        freeScansRemaining = await environment.aiScanQuota.remaining(isPro: entitlement.isPro)
    }

    private func restorePurchases() async {
        subscriptionMessage = nil
        do {
            let entitlement = try await environment.subscriptions.restore()
            await refreshSubscription()
            subscriptionMessage = entitlement.isPro ? "Pro restored." : "No Pro subscription found."
        } catch {
            subscriptionMessage = "Restore failed."
            environment.crashReporter.record(error: error, context: "subscriptions.restore")
        }
    }

    private func exportData() async {
        isPrivacyWorking = true
        privacyMessage = nil
        defer { isPrivacyWorking = false }
        do {
            let data = try await environment.dataMaintenance.exportJSON()
            exportDocument = ExportDocument(data: data)
        } catch {
            privacyMessage = error.localizedDescription
            environment.crashReporter.record(error: error, context: "privacy.export")
        }
    }

    private func deleteData() async {
        isPrivacyWorking = true
        privacyMessage = nil
        defer { isPrivacyWorking = false }
        do {
            try await environment.dataMaintenance.deleteAllLocalData()
            environment.analytics.track(.dataDeleted)
            privacyMessage = "Local data deleted. Restart onboarding from a fresh install state."
            await refresh()
        } catch {
            privacyMessage = error.localizedDescription
            environment.crashReporter.record(error: error, context: "privacy.delete")
        }
    }

    private func setHealthEnabled(_ enabled: Bool) async {
        isWorkingHealth = true
        defer { isWorkingHealth = false }
        healthMessage = nil
        do {
            if enabled {
                _ = try await environment.healthSync.requestAuthorization()
            }
            if var profile = try await environment.profileRepository.loadProfile() {
                profile.healthKitEnabled = enabled
                try await environment.profileRepository.saveProfile(profile)
            } else if enabled {
                var profile = UserProfile.blank
                profile.onboardingComplete = true
                profile.healthKitEnabled = true
                try await environment.profileRepository.saveProfile(profile)
            }
            healthStatusText = statusLabel(environment.healthSync.authorizationStatus())
            if enabled && environment.healthSync.authorizationStatus() == .sharingDenied {
                healthMessage = "Permission denied — logging stays on-device. You can change this in iOS Settings."
            }
        } catch {
            healthEnabled = false
            healthMessage = "Could not update Health settings."
            environment.crashReporter.record(error: error, context: "health.toggle")
        }
    }

    private func importWeights() async {
        isWorkingHealth = true
        defer { isWorkingHealth = false }
        do {
            let start = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            let count = try await environment.diary.importWeightsFromHealth(from: start, to: .now)
            healthMessage = count == 0
                ? "No new Health weights to import."
                : "Imported \(count) weight\(count == 1 ? "" : "s") from Apple Health."
        } catch {
            healthMessage = "Could not import Health weights."
            environment.crashReporter.record(error: error, context: "health.import")
        }
    }

    private func statusLabel(_ status: HealthAuthStatus) -> String {
        switch status {
        case .unavailable: "Unavailable on this device"
        case .notDetermined: "Not connected yet"
        case .sharingDenied: "Write access denied — diary still works"
        case .sharingAuthorized: "Connected"
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview("Settings") { SettingsView().environment(\.appEnvironment, .preview) }
