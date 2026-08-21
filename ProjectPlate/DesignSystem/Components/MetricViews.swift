import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space8) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(Typography.heroNumeric(36))
                .foregroundStyle(Color.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.supporting)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.cardPaddingLarge)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)\(subtitle.map { ", \($0)" } ?? "")")
    }
}

struct MacroProgressView: View {
    let label: String
    let current: Double
    let goal: Double
    let unit: String
    let tint: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space8) {
            HStack {
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(Int(current.rounded())) / \(Int(goal.rounded()))\(unit)")
                    .font(Typography.macroValue)
                    .foregroundStyle(Color.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.surfaceSecondary)
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(Int(current.rounded())) of \(Int(goal.rounded())) \(unit)")
    }
}

struct ConfidencePill: View {
    let confidence: MealConfidence

    var body: some View {
        Text(confidence.userLabel)
            .font(Typography.caption)
            .foregroundStyle(Color.brandInk)
            .padding(.horizontal, Spacing.space12)
            .padding(.vertical, Spacing.space8)
            .background(background)
            .clipShape(Capsule())
            .accessibilityLabel("Confidence: \(confidence.userLabel)")
    }

    private var background: Color {
        switch confidence {
        case .high: Color.brandPrimary.opacity(0.85)
        case .medium: Color.brandPrimary.opacity(0.45)
        case .low: Color.orange.opacity(0.35)
        }
    }
}

#Preview("Metrics") {
    VStack(spacing: Spacing.space16) {
        MetricCard(title: "Calories remaining", value: "1,042", subtitle: "1,138 eaten · 2,180 goal")
        MacroProgressView(label: "Protein", current: 82, goal: 164, unit: "g", tint: .macroProtein)
        ConfidencePill(confidence: .medium)
    }
    .padding()
    .background(Color.backgroundPrimary)
}
