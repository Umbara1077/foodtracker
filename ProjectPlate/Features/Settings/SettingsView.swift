import SwiftUI

struct SettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var showDesignSystem = false
    @State private var targetSummary: String = "Loading…"
    @State private var healthEnabled = false
    @State private var healthStatusText = "Checking…"
    @State private var healthMessage: String?
    @State private var isWorkingHealth = false

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
                        LabeledContent("Scans left today", value: "\(remaining) / \(limit)")
                    } else if environment.backendConfiguration.isCloudEnabled {
                        Text("Quota updates after the first cloud scan.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Set PLATE_API_BASE_URL to use the managed backend. Photos are never stored permanently.")
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Section("Privacy") {
                    Text("Cloud AI disclosure, export, and delete — Phase 10")
                        .foregroundStyle(Color.textSecondary)
                }
                Section("About") {
                    LabeledContent("Version", value: "0.8.0")
                    Text("Nutrition estimates are for informational tracking and may be inaccurate. This app does not provide medical advice.")
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
        healthStatusText = statusLabel(environment.healthSync.authorizationStatus())
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

#Preview("Settings") { SettingsView().environment(\.appEnvironment, .preview) }
