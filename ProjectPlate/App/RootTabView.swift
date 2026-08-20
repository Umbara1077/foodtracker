import SwiftUI

struct RootTabView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router

        Group {
            if router.isBootstrapping {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary.ignoresSafeArea())
            } else if router.needsOnboarding {
                OnboardingFlowView(
                    viewModel: OnboardingViewModel(
                        profileRepository: environment.profileRepository,
                        targetRepository: environment.targetRepository,
                        analytics: environment.analytics,
                        onFinished: { router.completeOnboarding() }
                    )
                )
            } else {
                ZStack(alignment: .bottom) {
                    TabView(selection: $router.selectedTab) {
                        TodayView()
                            .tabItem { Label(RootTab.today.title, systemImage: RootTab.today.systemImage) }
                            .tag(RootTab.today)

                        HistoryView()
                            .tabItem { Label(RootTab.history.title, systemImage: RootTab.history.systemImage) }
                            .tag(RootTab.history)

                        ProgressViewScreen()
                            .tabItem { Label(RootTab.progress.title, systemImage: RootTab.progress.systemImage) }
                            .tag(RootTab.progress)

                        SettingsView()
                            .tabItem { Label(RootTab.settings.title, systemImage: RootTab.settings.systemImage) }
                            .tag(RootTab.settings)
                    }

                    ScanFAB {
                        Task { await openScannerOrPaywall() }
                    }
                    .padding(.bottom, 8)
                    .offset(y: -28)
                    .accessibilitySortPriority(1)
                }
                .fullScreenCover(isPresented: $router.isScannerPresented) {
                    ScannerFlowView(
                        analysisService: environment.mealAnalysisService,
                        analytics: environment.analytics,
                        subscriptions: environment.subscriptions,
                        aiScanQuota: environment.aiScanQuota,
                        onQuotaExhausted: {
                            router.dismissScanner()
                            router.openPaywall()
                        }
                    )
                }
                .sheet(isPresented: $router.isPaywallPresented) {
                    PaywallView {
                        // After unlock, user can tap Scan again.
                    }
                }
                .sheet(isPresented: $router.isConsentPresented) {
                    CloudAIConsentView(
                        onAccept: {
                            Task { await acceptConsentAndScan() }
                        },
                        onDecline: {
                            environment.analytics.track(.cloudAIConsentDeclined)
                        }
                    )
                }
            }
        }
        .task {
            await bootstrap()
        }
    }

    private func openScannerOrPaywall() async {
        if await needsCloudAIConsent() {
            router.openConsent()
            return
        }
        let entitlement = await environment.subscriptions.currentEntitlement()
        let remaining = await environment.aiScanQuota.remaining(isPro: entitlement.isPro)
        if remaining <= 0 {
            environment.analytics.track(.paywallViewed)
            router.openPaywall()
        } else {
            router.openScanner()
        }
    }

    private func needsCloudAIConsent() async -> Bool {
        let profile = try? await environment.profileRepository.loadProfile()
        return profile?.cloudAIConsentVersion != PrivacyConstants.cloudAIConsentVersion
    }

    private func acceptConsentAndScan() async {
        environment.analytics.track(.cloudAIConsentAccepted)
        do {
            var profile = try await environment.profileRepository.loadProfile() ?? {
                var blank = UserProfile.blank
                blank.onboardingComplete = true
                return blank
            }()
            profile.cloudAIConsentVersion = PrivacyConstants.cloudAIConsentVersion
            profile.cloudAIConsentDate = .now
            try await environment.profileRepository.saveProfile(profile)
        } catch {
            environment.crashReporter.record(error: error, context: "consent.save")
        }
        router.dismissConsent()
        await openScannerOrPaywall()
    }

    private func bootstrap() async {
        do {
            if let profile = try await environment.profileRepository.loadProfile() {
                router.needsOnboarding = !profile.onboardingComplete
            } else {
                router.needsOnboarding = true
            }
        } catch {
            router.needsOnboarding = true
        }
        router.isBootstrapping = false
    }
}

private struct ScanFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.brandInk)
                .frame(width: 60, height: 60)
                .background(Color.brandPrimary, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Scan meal")
        .accessibilityHint("Opens the meal scanner")
    }
}

#Preview("Root tabs") {
    RootTabView()
        .environment(\.appEnvironment, .preview)
}
