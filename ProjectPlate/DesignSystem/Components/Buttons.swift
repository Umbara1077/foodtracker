import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.space16)
                .foregroundStyle(Color.brandInk)
                .background(isEnabled ? Color.brandPrimary : Color.brandPrimary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.space16)
                .foregroundStyle(Color.textPrimary)
                .background(Color.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview("Buttons") {
    VStack(spacing: Spacing.space16) {
        PrimaryButton(title: "Continue", action: {})
        SecondaryButton(title: "Not now", action: {})
    }
    .padding(Spacing.screenHorizontal)
    .background(Color.backgroundPrimary)
}
