import SwiftUI

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
    @Environment(\.appEnvironment) private var environment
    @State private var showDesignSystem = false
    @State private var targetSummary: String = "Loading…"

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
                Section("Privacy") {
                    Text("Cloud AI disclosure, export, and delete — Phase 10")
                        .foregroundStyle(Color.textSecondary)
                }
                Section("About") {
                    LabeledContent("Version", value: "0.3.0")
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
                if let target = try? await environment.targetRepository.currentTarget(on: .now) {
                    targetSummary = "\(target.calories) cal · P \(target.proteinGrams)g · C \(target.carbGrams)g · F \(target.fatGrams)g"
                } else {
                    targetSummary = "No target saved yet."
                }
            }
        }
    }
}

#Preview("Progress") { ProgressViewScreen() }
#Preview("Settings") { SettingsView().environment(\.appEnvironment, .preview) }
