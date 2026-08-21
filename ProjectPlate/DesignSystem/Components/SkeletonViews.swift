import SwiftUI

/// Lightweight loading placeholders for Today (PRODUCT_SPEC §6.1). Respects Reduced Motion.
struct PlateSkeletonCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var height: CGFloat = 88

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .fill(Color.surfaceSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.surfaceSecondary,
                                    Color.surfacePrimary.opacity(0.55),
                                    Color.surfaceSecondary,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(0.85)
                }
            }
            .accessibilityLabel("Loading")
            .accessibilityAddTraits(.updatesFrequently)
    }
}

struct TodayLoadingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space16) {
            PlateSkeletonCard(height: 120)
            PlateSkeletonCard(height: 56)
            PlateSkeletonCard(height: 56)
            PlateSkeletonCard(height: 56)
            PlateSkeletonCard(height: 160)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading today’s diary")
    }
}

#Preview {
    TodayLoadingSkeleton()
        .padding()
        .background(Color.backgroundPrimary)
}
