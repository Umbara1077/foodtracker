import SwiftUI

/// Semantic colors from PRODUCT_SPEC §8.2. Prefer these over raw hex in views.
extension Color {
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let surfacePrimary = Color("SurfacePrimary")
    static let surfaceSecondary = Color("SurfaceSecondary")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let separator = Color("Separator")
    static let brandPrimary = Color("BrandPrimary")
    static let brandPrimaryPressed = Color("BrandPrimaryPressed")
    static let brandInk = Color("BrandInk")

    static let macroProtein = Color("MacroProtein")
    static let macroCarbs = Color("MacroCarbs")
    static let macroFat = Color("MacroFat")
}

enum Spacing {
    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space40: CGFloat = 40

    static let screenHorizontal: CGFloat = space20
    static let cardPaddingCompact: CGFloat = space16
    static let cardPaddingLarge: CGFloat = space20
}

enum Radius {
    static let chip: CGFloat = 10
    static let control: CGFloat = 14
    static let card: CGFloat = 20
    static let heroCard: CGFloat = 26
    static let sheet: CGFloat = 30
}

enum Typography {
    static func heroNumeric(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let screenTitle = Font.system(size: 28, weight: .bold)
    static let sectionHeading = Font.system(size: 20, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let supporting = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 13, weight: .medium)
    static let macroValue = Font.system(size: 17, weight: .semibold, design: .rounded)
}
