import StoreKit
import SwiftUI
import UIKit
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
#if !LEGACY_BUILD
    @AppStorage(TodayLiveActivityPolicy.preferenceKey) private var liveActivityEnabled = true
#endif
    @AppStorage(CloudSyncPreference.enabledKey) private var iCloudSyncEnabled = false
    @AppStorage(AdaptiveGoalPreference.enabledKey) private var adaptiveGoalsEnabled = true
    @AppStorage(CoachInsightPreference.enabledKey) private var coachInsightsEnabled = true
    @AppStorage(ChallengePreference.enabledKey) private var challengesEnabled = true
    @AppStorage(MealPlanPreference.enabledKey) private var mealPlanEnabled = true
    @AppStorage(HouseholdPreference.enabledKey) private var householdEnabled = true
    @AppStorage(MicronutrientPreference.enabledKey) private var micronutrientsEnabled = true
    @AppStorage(MealReminderPreference.enabledKey) private var mealRemindersEnabled = false
    @State private var consentVersionLabel = "Not answered"
    @State private var privacyMessage: String?
    @State private var isPrivacyWorking = false
    @State private var iCloudSyncMessage: String?
    @State private var isSyncing = false
    @State private var lastSyncLabel = "Never"
    @State private var exportFilename = "project-plate-export"
    @State private var exportContentType: UTType = .json

    private var cloudAIModeLabel: String {
        let config = BackendConfiguration.resolved()
        switch config.sourceLabel {
        case "custom": return "Custom gateway"
        case "managed": return "Managed gateway"
        default: return "On-device mock"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    Text(targetSummary)
                        .font(Typography.supporting)
                        .foregroundStyle(Color.textPrimary)
                    NavigationLink {
                        TargetEditorView()
                    } label: {
                        Label("Edit calorie & macro targets", systemImage: "slider.horizontal.3")
                    }
                    Text("Edits apply from today forward. History keeps earlier targets for charts.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
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
                    Button("Manage subscription") {
                        Task { await manageSubscriptions() }
                    }
                    if let subscriptionMessage {
                        Text(subscriptionMessage)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("History and manual logging stay available on Free. Subscriptions renew automatically via Apple ID unless cancelled.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Apple Health") {
                    Toggle("Sync meals & weight", isOn: $healthEnabled)
                        .disabled(!environment.healthSync.isDataAvailable || isWorkingHealth)
                        .onChangeCompat(of: healthEnabled) { enabled in
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
#if !LEGACY_BUILD
                Section("iCloud") {
                    Toggle("Sync diary across devices", isOn: $iCloudSyncEnabled)
                        .onChangeCompat(of: iCloudSyncEnabled) { enabled in
                            CloudSyncPreference.setEnabled(enabled)
                            if enabled {
                                Task { await runCloudSync(triggeredByToggle: true) }
                            }
                        }
                    LabeledContent("Last sync", value: lastSyncLabel)
                    Button("Sync now") {
                        Task { await runCloudSync(triggeredByToggle: false) }
                    }
                    .disabled(!iCloudSyncEnabled || isSyncing)
                    Text("Meals, weight, targets, and saved meals use your private iCloud database. Photos stay on this iPhone.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    if let iCloudSyncMessage {
                        Text(iCloudSyncMessage)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
#endif
                Section("Cloud AI") {
                    LabeledContent("Mode", value: cloudAIModeLabel)
                    if let remaining = environment.scanQuota.remaining,
                       let limit = environment.scanQuota.dailyLimit {
                        LabeledContent("Cloud quota", value: "\(remaining) / \(limit)")
                    } else if BackendConfiguration.resolved().isCloudEnabled {
                        Text("Cloud quota updates after the first cloud scan.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("On-device mock until you set a managed backend or custom gateway. Photos are never stored permanently.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    NavigationLink {
                        CustomGatewaySettingsView()
                    } label: {
                        Label("Custom gateway", systemImage: "server.rack")
                    }
                    Text("Advanced — use your own HTTPS meal-analysis endpoint. Upstream API keys stay on your server.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Reminders") {
                    Toggle("Meal logging reminders", isOn: $mealRemindersEnabled)
                        .onChangeCompat(of: mealRemindersEnabled) { enabled in
                            MealReminderPreference.setEnabled(enabled)
                            Task { await MealReminderScheduler.refresh() }
                        }
                    if mealRemindersEnabled {
                        ForEach(ReminderMeal.allCases) { meal in
                            Stepper(
                                "\(meal.title): \(MealReminderPreference.hour(for: meal)):00",
                                value: Binding(
                                    get: { MealReminderPreference.hour(for: meal) },
                                    set: { newValue in
                                        MealReminderPreference.setHour(newValue, for: meal)
                                        Task { await MealReminderScheduler.refresh() }
                                    }
                                ),
                                in: 5...22
                            )
                        }
                    }
                    Text("Optional. Permission is requested only when you turn reminders on. Copy stays supportive — never guilt.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Goals") {
                    Toggle("Suggest adaptive calorie tweaks", isOn: $adaptiveGoalsEnabled)
                        .onChangeCompat(of: adaptiveGoalsEnabled) { enabled in
                            AdaptiveGoalPreference.setEnabled(enabled)
                            if enabled {
                                AdaptiveGoalPreference.clearDismissal()
                            }
                        }
                    Text("Uses recent weight trend and your goal to optionally nudge calories on Progress. Never auto-applies.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    Toggle("Show coach tips", isOn: $coachInsightsEnabled)
                        .onChangeCompat(of: coachInsightsEnabled) { enabled in
                            CoachInsightPreference.setEnabled(enabled)
                        }
                    Text("Supportive local tips from your recent logging. Not medical advice.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    Toggle("Show weekly challenges", isOn: $challengesEnabled)
                        .onChangeCompat(of: challengesEnabled) { enabled in
                            ChallengePreference.setEnabled(enabled)
                        }
                    Text("Optional tracking goals on Progress. Pausing never costs a streak.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    Toggle("Show meal planning", isOn: $mealPlanEnabled)
                        .onChangeCompat(of: mealPlanEnabled) { enabled in
                            MealPlanPreference.setEnabled(enabled)
                        }
                    Text("Plan upcoming meals on Today. Local only — not a grocery or shopping list.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    Toggle("Show family plan", isOn: $householdEnabled)
                        .onChangeCompat(of: householdEnabled) { enabled in
                            HouseholdPreference.setEnabled(enabled)
                        }
                    Text("Local household roster on Progress. Cloud sharing is not on yet.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    Toggle("Show fiber, sugar & sodium", isOn: $micronutrientsEnabled)
                        .onChangeCompat(of: micronutrientsEnabled) { enabled in
                            MicronutrientPreference.setEnabled(enabled)
                        }
                    Text("Soft daily targets on Today and weekly averages on Progress. Not medical advice.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
#if LEGACY_BUILD
                Section("Xcode 14 build") {
                    Text("This build stores your diary locally on this iPhone (JSON files). iCloud sync, Home Screen widget, Apple Watch, and Live Activity need the full Xcode 16 project (`./scripts/bootstrap-ios.sh`).")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
#else
                Section("Lock Screen") {
                    Toggle("Show today’s calories", isOn: $liveActivityEnabled)
                        .accessibilityHint("Updates a Live Activity on the Lock Screen and Dynamic Island while you log meals")
                        .onChangeCompat(of: liveActivityEnabled) { enabled in
                            TodayLiveActivityPolicy.setEnabled(enabled)
                            if !enabled {
                                Task { await TodayLiveActivityController.endAll() }
                            }
                        }
                    Text("Appears after onboarding when you open Today. Ends at midnight.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Apple Watch") {
                    Text("Install the Project Plate watch app for a glance of remaining calories and protein. It updates when you open Today on iPhone.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
#endif
                Section("Family") {
                    NavigationLink {
                        HouseholdSettingsView()
                    } label: {
                        Label("Family plan", systemImage: "person.3")
                    }
                    Text("Local household members and invite code. Shared cloud diaries come later.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Privacy") {
                    LabeledContent("AI consent", value: consentVersionLabel)

                    if CloudAIConsentStore.decision() != .accepted {
                        Button("Allow cloud meal analysis") {
                            Task { await setCloudAIConsent(.accepted) }
                        }
                    }
                    if CloudAIConsentStore.decision() != .declined {
                        Button("Use on-device analysis only") {
                            Task { await setCloudAIConsent(.declined) }
                        }
                    }

                    NavigationLink("Privacy policy") {
                        PrivacyPolicyView()
                    }
                    NavigationLink("Terms of use") {
                        TermsOfUseView()
                    }

                    Button("Export JSON") {
                        Task { await exportData(asCSV: false) }
                    }
                    .disabled(isPrivacyWorking)

                    Button("Export CSV") {
                        Task { await exportData(asCSV: true) }
                    }
                    .disabled(isPrivacyWorking)

                    Button("Delete my data", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(isPrivacyWorking)

                    Text("Delete removes diary data on this iPhone and, when iCloud sync is on, marks synced copies deleted in your private iCloud database.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)

                    if let privacyMessage {
                        Text(privacyMessage)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                if BuildChannel.showsBetaTools {
                    Section("TestFlight") {
                        NavigationLink {
                            TestFlightToolsView()
                        } label: {
                            Label("Beta tools", systemImage: "airplane")
                        }
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: AppVersion.display())
                    Link("Support", destination: PrivacyConstants.supportURL)
                    NavigationLink("Acknowledgments") {
                        AcknowledgmentsView()
                    }
                    if PrivacyConstants.usesPlaceholderLegalURLs {
                        Text("Set PLATE_PRIVACY_POLICY_URL and PLATE_TERMS_URL to your live https pages before App Store submission.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    if PrivacyConstants.usesPlaceholderSupportURL {
                        Text("Set PLATE_SUPPORT_URL to your real support page or mailto: address before submission.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("Nutrition estimates are for informational tracking and may be inaccurate. This app does not provide medical advice.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    #if DEBUG
                    Text("DEBUG: working title — confirm trademark clearance before public naming.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    #endif
                }
                #if DEBUG
                Section("Debug") {
                    Button("Design system gallery") {
                        showDesignSystem = true
                    }
                }
                #endif
            }
            .plateReadableWidth()
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
                contentType: exportContentType,
                defaultFilename: exportFilename
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
                "Delete all data on this iPhone? If iCloud sync is on, synced copies are marked deleted too. This cannot be undone.",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    Task { await deleteData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes meals, weight, saved meals, and resets onboarding. With iCloud sync on, matching private-database copies are marked deleted.")
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
        }
        consentVersionLabel = CloudAIConsentStore.statusLabel()
        healthStatusText = statusLabel(environment.healthSync.authorizationStatus())
        refreshLastSyncLabel()
        await refreshSubscription()
    }

    private func refreshLastSyncLabel() {
        if let date = CloudSyncPreference.lastSyncDate() {
            lastSyncLabel = date.formatted(date: .abbreviated, time: .shortened)
        } else {
            lastSyncLabel = "Never"
        }
    }

    private func runCloudSync(triggeredByToggle: Bool) async {
        isSyncing = true
        iCloudSyncMessage = triggeredByToggle ? "Starting iCloud sync…" : "Syncing…"
        defer { isSyncing = false }
        do {
            try await environment.diarySync.syncIfEnabled()
            environment.analytics.track(.iCloudSyncCompleted)
            refreshLastSyncLabel()
            iCloudSyncMessage = "Sync finished."
        } catch let error as SyncServiceError {
            iCloudSyncMessage = error.errorDescription
        } catch {
            iCloudSyncMessage = error.localizedDescription
            environment.crashReporter.record(error: error, context: "icloud.sync")
        }
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
            if entitlement.isPro {
                environment.analytics.track(.purchaseRestored)
            }
            subscriptionMessage = entitlement.isPro ? "Pro restored." : "No Pro subscription found."
        } catch {
            subscriptionMessage = "Restore failed."
            environment.crashReporter.record(error: error, context: "subscriptions.restore")
        }
    }

    private func manageSubscriptions() async {
        subscriptionMessage = nil
        do {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
                await UIApplication.shared.open(SubscriptionLegalCopy.manageSubscriptionsURL)
                return
            }
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            await UIApplication.shared.open(SubscriptionLegalCopy.manageSubscriptionsURL)
        }
    }

    private func setCloudAIConsent(_ decision: CloudAIConsentStore.Decision) async {
        CloudAIConsentStore.set(decision)
        do {
            var profile = try await environment.profileRepository.loadProfile() ?? {
                var blank = UserProfile.blank
                blank.onboardingComplete = true
                return blank
            }()
            switch decision {
            case .accepted:
                profile.cloudAIConsentVersion = PrivacyConstants.cloudAIConsentVersion
                profile.cloudAIConsentDate = .now
                environment.analytics.track(.cloudAIConsentAccepted)
            case .declined:
                profile.cloudAIConsentVersion = nil
                profile.cloudAIConsentDate = nil
                environment.analytics.track(.cloudAIConsentDeclined)
            }
            try await environment.profileRepository.saveProfile(profile)
        } catch {
            environment.crashReporter.record(error: error, context: "consent.settings")
        }
        consentVersionLabel = CloudAIConsentStore.statusLabel()
        privacyMessage = decision == .accepted
            ? "Cloud meal analysis enabled."
            : "Cloud upload off. Photo scans stay on-device."
    }

    private func exportData(asCSV: Bool) async {
        isPrivacyWorking = true
        privacyMessage = nil
        defer { isPrivacyWorking = false }
        do {
            if asCSV {
                let data = try await environment.dataMaintenance.exportCSV()
                exportContentType = .commaSeparatedText
                exportFilename = "project-plate-meals"
                exportDocument = ExportDocument(data: data, contentType: .commaSeparatedText)
            } else {
                let data = try await environment.dataMaintenance.exportJSON()
                exportContentType = .json
                exportFilename = "project-plate-export"
                exportDocument = ExportDocument(data: data, contentType: .json)
            }
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
            try await environment.dataMaintenance.deleteAllLocalData(purgeCloudCopies: true)
            environment.analytics.track(.dataDeleted)
#if !LEGACY_BUILD
            await TodayLiveActivityController.endAll()
#endif
            refreshLastSyncLabel()
            privacyMessage = iCloudSyncEnabled
                ? "Data deleted on this iPhone and marked deleted in iCloud when sync was on."
                : "Local data deleted. Onboarding will restart on next cold start if profile was reset."
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
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    var contentType: UTType

    init(data: Data, contentType: UTType = .json) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#if !LEGACY_BUILD
#Preview("Settings") { SettingsView().environment(\.appEnvironment, .preview) }
#endif
