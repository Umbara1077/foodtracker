import SwiftUI

struct RootTabView: View {
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router

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
                router.openScanner()
            }
            .padding(.bottom, 8)
            // Sit just above the tab bar.
            .offset(y: -28)
            .accessibilitySortPriority(1)
        }
        .fullScreenCover(isPresented: $router.isScannerPresented) {
            ScannerPlaceholderView(onClose: router.dismissScanner)
        }
    }
}

/// Elevated central Scan action visually attached to the tab bar (spec §9).
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
