import SwiftUI

/// iPad / wide-layout helpers (PRODUCT_SPEC §6.3 iPad-specific layout).
enum PlateLayout {
    /// Comfortable reading column on large screens.
    static let maxReadableWidth: CGFloat = 720
    /// Two-pane content width before splitting Today / Progress.
    static let wideSplitMinimum: CGFloat = 900

    static func prefersWideSplit(horizontalSizeClass: UserInterfaceSizeClass?, width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= wideSplitMinimum
    }

    static func contentMaxWidth(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        horizontalSizeClass == .regular ? maxReadableWidth : nil
    }
}

struct PlateReadableWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: PlateLayout.contentMaxWidth(horizontalSizeClass: horizontalSizeClass) ?? .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Centers content and caps width on iPad / regular size classes.
    func plateReadableWidth() -> some View {
        modifier(PlateReadableWidth())
    }
}
