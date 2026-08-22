import SwiftUI

// MARK: - onChange (iOS 16 single-value vs iOS 17 two-value)

extension View {
    /// Back-deploys the two-parameter `onChange` shape used across the app.
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value, action)
        } else {
            onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }

    /// Convenience when only the new value matters.
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (_ newValue: V) -> Void
    ) -> some View {
        onChangeCompat(of: value) { _, newValue in
            action(newValue)
        }
    }
}

// MARK: - Empty states (ContentUnavailableView is iOS 17+)

struct PlateEmptyState: View {
    var title: String
    var systemImage: String
    var description: Text?

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    init(_ title: String, systemImage: String, description: String) {
        self.init(title, systemImage: systemImage, description: Text(description))
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if let description {
                    description
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PlateUnavailableView<Label: View, Description: View, Actions: View>: View {
    @ViewBuilder var label: () -> Label
    @ViewBuilder var description: () -> Description
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(content: label, description: description, actions: actions)
        } else {
            VStack(spacing: 16) {
                label()
                description()
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                actions()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Tab style (sidebarAdaptable is iOS 18+)

struct PlateTabStyleModifier: ViewModifier {
    var horizontalSizeClass: UserInterfaceSizeClass?

    func body(content: Content) -> some View {
        #if LEGACY_BUILD
        content
        #else
        if horizontalSizeClass == .regular {
            if #available(iOS 18.0, *) {
                content.tabViewStyle(.sidebarAdaptable)
            } else {
                content
            }
        } else {
            content
        }
        #endif
    }
}
