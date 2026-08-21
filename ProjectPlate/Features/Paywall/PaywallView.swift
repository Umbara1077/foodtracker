import StoreKit
import SwiftUI
import UIKit

@MainActor
@Observable
final class PaywallViewModel {
    private let subscriptions: any SubscriptionServicing

    var products: [SubscriptionProductInfo] = []
    var selectedProductID: String = SubscriptionProductID.annual
    var entitlement: ProEntitlement = .free
    var isLoading = true
    var isPurchasing = false
    var errorMessage: String?
    var statusMessage: String?

    init(subscriptions: any SubscriptionServicing) {
        self.subscriptions = subscriptions
    }

    var selectedProduct: SubscriptionProductInfo? {
        products.first(where: { $0.id == selectedProductID }) ?? products.first
    }

    var subscribeTitle: String {
        guard let product = selectedProduct else {
            return SubscriptionLegalCopy.subscribeButtonTitle(
                displayPrice: nil,
                isAnnual: true,
                isPurchasing: isPurchasing
            )
        }
        return SubscriptionLegalCopy.subscribeButtonTitle(
            displayPrice: product.displayPrice,
            isAnnual: product.isAnnual,
            isPurchasing: isPurchasing
        )
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await subscriptions.loadProducts()
            entitlement = await subscriptions.currentEntitlement()
            if products.contains(where: { $0.id == SubscriptionProductID.annual }) {
                selectedProductID = SubscriptionProductID.annual
            } else if let first = products.first {
                selectedProductID = first.id
            }
        } catch {
            errorMessage = "Could not load subscriptions."
        }
        isLoading = false
    }

    func purchase() async -> Bool {
        isPurchasing = true
        errorMessage = nil
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            entitlement = try await subscriptions.purchase(productID: selectedProductID)
            return entitlement.isPro
        } catch let error as PurchaseError where error == .userCancelled {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            entitlement = try await subscriptions.restore()
            statusMessage = entitlement.isPro ? "Pro restored." : "No Pro subscription found."
        } catch {
            errorMessage = "Restore failed."
        }
    }

    func manageSubscriptions() async {
        errorMessage = nil
        do {
            guard let scene = Self.activeWindowScene() else {
                await openManageSubscriptionsURL()
                return
            }
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            await openManageSubscriptionsURL()
        }
    }

    private func openManageSubscriptionsURL() async {
        await UIApplication.shared.open(SubscriptionLegalCopy.manageSubscriptionsURL)
    }

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: PaywallViewModel?
    var onUnlocked: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Project Plate Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = PaywallViewModel(subscriptions: environment.subscriptions)
                viewModel = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: PaywallViewModel) -> some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space24) {
                VStack(alignment: .leading, spacing: Spacing.space12) {
                    Text("Project Plate")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Color.brandPrimary)
                    Text("Log food in seconds.")
                        .font(Typography.heroNumeric(36))
                        .foregroundStyle(Color.textPrimary)
                    Text("Unlock unlimited AI meal scans beyond the Free daily limit. Diary and history stay yours either way.")
                        .font(Typography.supporting)
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: Spacing.space12) {
                    benefit("Unlimited AI meal scans", systemImage: "camera.fill")
                    benefit("Faster scan corrections", systemImage: "slider.horizontal.3")
                    benefit("Priority cloud analysis", systemImage: "bolt.horizontal.circle.fill")
                }

                if viewModel.isLoading {
                    ProgressView("Loading plans…")
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: Spacing.space12) {
                        ForEach(viewModel.products) { product in
                            planRow(product, selected: viewModel.selectedProductID == product.id) {
                                viewModel.selectedProductID = product.id
                            }
                        }
                    }
                }

                if let product = viewModel.selectedProduct {
                    Text(
                        SubscriptionLegalCopy.selectedPlanDisclosure(
                            displayPrice: product.displayPrice,
                            periodLabel: product.periodLabel,
                            isAnnual: product.isAnnual
                        )
                    )
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(
                        "\(product.periodLabel) plan, \(product.displayPrice) per \(SubscriptionLegalCopy.periodUnitLabel(isAnnual: product.isAnnual)), auto-renewable"
                    )
                }

                if let error = viewModel.errorMessage {
                    Text(error).font(Typography.caption).foregroundStyle(Color.statusError)
                }
                if let status = viewModel.statusMessage {
                    Text(status).font(Typography.caption).foregroundStyle(Color.textSecondary)
                }

                PrimaryButton(
                    title: viewModel.subscribeTitle,
                    isEnabled: !viewModel.isPurchasing && !viewModel.products.isEmpty
                ) {
                    Task {
                        if await viewModel.purchase() {
                            onUnlocked?()
                            dismiss()
                        }
                    }
                }

                VStack(spacing: Spacing.space12) {
                    Button("Restore purchases") {
                        Task { await viewModel.restore() }
                    }
                    .disabled(viewModel.isPurchasing)

                    Button("Manage subscription") {
                        Task { await viewModel.manageSubscriptions() }
                    }
                    .disabled(viewModel.isPurchasing)
                }
                .font(Typography.supporting.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)

                legalFooter
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.space24)
        }
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: Spacing.space12) {
            Text(SubscriptionLegalCopy.autoRenewSummary)
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(SubscriptionLegalCopy.freeKeepsHistory)
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: Spacing.space16) {
                Link("Privacy Policy", destination: PrivacyConstants.privacyPolicyURL)
                Link("Terms of Use", destination: PrivacyConstants.termsURL)
            }
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(Color.brandInk)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func benefit(_ title: String, systemImage: String) -> some View {
        HStack(spacing: Spacing.space12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.brandInk)
                .frame(width: 28)
            Text(title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(Spacing.cardPaddingCompact)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private func planRow(
        _ product: SubscriptionProductInfo,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.periodLabel)
                            .font(Typography.body.weight(.semibold))
                        if product.isAnnual {
                            Text("Best value")
                                .font(Typography.caption)
                                .foregroundStyle(Color.brandInk)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.brandPrimary.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        }
                    }
                    Text("\(product.displayName) · \(SubscriptionLegalCopy.pricePeriodLine(displayPrice: product.displayPrice, isAnnual: product.isAnnual))")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(Spacing.cardPaddingCompact)
            .background(selected ? Color.brandPrimary.opacity(0.25) : Color.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(selected ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(product.periodLabel), \(product.displayPrice) per \(SubscriptionLegalCopy.periodUnitLabel(isAnnual: product.isAnnual))"
        )
    }
}

#Preview {
    PaywallView()
        .environment(\.appEnvironment, .preview)
}
