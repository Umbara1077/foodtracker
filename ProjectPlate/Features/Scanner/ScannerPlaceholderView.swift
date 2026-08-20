import SwiftUI

/// Full-screen Scan placeholder — real AVFoundation camera arrives in Phase 3.
struct ScannerPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: Spacing.space24) {
                Text("Meal scan")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(.white)

                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.brandPrimary.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .frame(maxWidth: 320)
                    .frame(height: 220)
                    .overlay {
                        VStack(spacing: Spacing.space12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.brandPrimary)
                            Text("Fit the whole plate in frame")
                                .font(Typography.supporting)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }

                Text("Camera capture and AI analysis ship in Phases 3–5. This shell verifies navigation and presentation.")
                    .font(Typography.supporting)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.space32)

                PrimaryButton(title: "Close", action: onClose)
                    .padding(.horizontal, Spacing.space32)
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    ScannerPlaceholderView(onClose: {})
}
