import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "History",
                systemImage: "calendar",
                description: Text("Past days and meal duplication land in Phase 2.")
            )
            .navigationTitle("History")
        }
    }
}

struct ProgressViewScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Progress",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Weight and consistency charts land in Phase 7.")
            )
            .navigationTitle("Progress")
        }
    }
}

struct SettingsView: View {
    @State private var showDesignSystem = false

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    Text("Goal & targets — Phase 1")
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Privacy") {
                    Text("Cloud AI disclosure, export, and delete — Phase 10")
                        .foregroundStyle(Color.textSecondary)
                }
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
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
        }
    }
}

#Preview("History") { HistoryView() }
#Preview("Progress") { ProgressViewScreen() }
#Preview("Settings") { SettingsView() }
