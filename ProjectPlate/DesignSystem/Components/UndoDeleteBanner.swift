import SwiftUI

/// Transient undo affordance after deleting a meal.
struct UndoDeleteBanner: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.space12) {
            Text(message)
                .font(Typography.supporting)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Undo") {
                onUndo()
            }
            .font(Typography.supporting.weight(.semibold))
            .foregroundStyle(Color.brandInk)
            .padding(.horizontal, Spacing.space12)
            .padding(.vertical, Spacing.space8)
            .background(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .accessibilityLabel("Undo delete")

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(Spacing.space8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, Spacing.space16)
        .padding(.vertical, Spacing.space12)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.space16)
        .accessibilityElement(children: .contain)
    }
}
