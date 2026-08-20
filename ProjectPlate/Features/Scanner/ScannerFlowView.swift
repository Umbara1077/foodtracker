import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class ScannerViewModel {
    enum Phase: Equatable {
        case camera
        case retake(UIImage)
        case analyzing(UIImage, MealAnalysisStage)
        case result(ReviewableMealDraft)
        case failed(message: String, image: UIImage?, canRetryAnalysis: Bool)
    }

    private let analysisService: any MealAnalysisServing
    private let cameraAuth: any CameraAuthorizing
    private let analytics: any AnalyticsClient
    private let subscriptions: (any SubscriptionServicing)?
    private let aiScanQuota: LocalAIScanQuotaStore?
    var onQuotaExhausted: (() -> Void)?

    var phase: Phase = .camera
    var authorization: CameraAuthorizationStatus = .notDetermined
    var cameraController = CameraSessionController()
    var isFlashOn = false
    var pickerItem: PhotosPickerItem?
    var analyzeImmediately = false
    var slowAnalysisHint: String?
    var showManualAdd = false
    private var analysisStartedAt: Date?

    init(
        analysisService: any MealAnalysisServing,
        cameraAuth: any CameraAuthorizing = SystemCameraAuthorization(),
        analytics: any AnalyticsClient,
        subscriptions: (any SubscriptionServicing)? = nil,
        aiScanQuota: LocalAIScanQuotaStore? = nil,
        onQuotaExhausted: (() -> Void)? = nil
    ) {
        self.analysisService = analysisService
        self.cameraAuth = cameraAuth
        self.analytics = analytics
        self.subscriptions = subscriptions
        self.aiScanQuota = aiScanQuota
        self.onQuotaExhausted = onQuotaExhausted
        self.authorization = cameraAuth.status()
    }

    func onAppear() async {
        analytics.track(.scannerOpened)
        authorization = cameraAuth.status()
        if authorization == .notDetermined {
            // Pre-permission: wait until user taps shutter / enable.
            return
        }
        if authorization == .authorized {
            await startCameraIfPossible()
        }
    }

    func requestCameraAndStart() async {
        let granted = await cameraAuth.requestAccess()
        authorization = cameraAuth.status()
        if granted {
            await startCameraIfPossible()
        }
    }

    func startCameraIfPossible() async {
        do {
            try cameraController.configure()
            cameraController.start()
        } catch {
            // Simulator / no camera hardware — keep library path available.
            cameraController.errorMessage = "Camera unavailable on this device. Choose a photo instead."
        }
    }

    func capture() async {
        if authorization != .authorized {
            await requestCameraAndStart()
            guard authorization == .authorized else { return }
        }
        do {
            let data = try await cameraController.capturePhoto()
            guard let image = UIImage(data: data) else {
                presentFailure(
                    message: ScanRetryPolicy.userMessage(for: MealScanError.invalidImage),
                    image: nil,
                    error: MealScanError.invalidImage
                )
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if analyzeImmediately {
                await analyze(image: image)
            } else {
                phase = .retake(image)
            }
        } catch {
            presentFailure(
                message: ScanRetryPolicy.userMessage(for: error),
                image: nil,
                error: error
            )
        }
    }

    func importPickerItem() async {
        guard let pickerItem else { return }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                presentFailure(
                    message: ScanRetryPolicy.userMessage(for: MealScanError.invalidImage),
                    image: nil,
                    error: MealScanError.invalidImage
                )
                return
            }
            phase = .retake(image)
        } catch {
            presentFailure(
                message: ScanRetryPolicy.userMessage(for: error),
                image: nil,
                error: error
            )
        }
        self.pickerItem = nil
    }

    func useSampleFixture() async {
        // 1x1 JPEG so analysis has non-empty data; mock ignores pixels.
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        await analyze(image: image)
    }

    func analyze(image: UIImage, isAutomaticRetry: Bool = false) async {
        guard let jpeg = MealImageEncoder.jpegData(from: image) else {
            presentFailure(
                message: ScanRetryPolicy.userMessage(for: MealScanError.invalidImage),
                image: image,
                error: MealScanError.invalidImage
            )
            return
        }

        let isPro = await subscriptions?.currentEntitlement().isPro ?? true
        if let aiScanQuota {
            let allowed = await aiScanQuota.canConsume(isPro: isPro)
            if !allowed {
                presentFailure(
                    message: ScanRetryPolicy.userMessage(for: MealScanError.quotaExceeded),
                    image: image,
                    error: MealScanError.quotaExceeded
                )
                onQuotaExhausted?()
                return
            }
        }

        if isAutomaticRetry {
            analytics.track(.scanRetried)
        }

        phase = .analyzing(image, .preparingImage)
        analysisStartedAt = .now
        slowAnalysisHint = nil
        let hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            if case .analyzing = phase {
                slowAnalysisHint = "Still working — mixed meals can take a little longer."
            }
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            if case .analyzing = phase {
                slowAnalysisHint = "This is taking longer than usual. You can cancel and retry."
            }
        }
        defer { hintTask.cancel() }

        do {
            let draft = try await analysisService.analyze(
                imageData: jpeg,
                context: .init(
                    mealHint: .inferred(),
                    localeIdentifier: Locale.current.identifier,
                    units: .metric
                ),
                onStage: { [weak self] stage in
                    Task { @MainActor in
                        guard let self else { return }
                        if case .analyzing(let img, _) = self.phase {
                            self.phase = .analyzing(img, stage)
                        }
                    }
                }
            )
            if draft.items.isEmpty {
                presentFailure(
                    message: ScanRetryPolicy.userMessage(for: MealScanError.invalidStructuredResponse, emptyPlate: true),
                    image: image,
                    error: MealScanError.invalidStructuredResponse
                )
                return
            }
            // Consume only after a valid structured result.
            _ = await aiScanQuota?.consume(isPro: isPro)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            slowAnalysisHint = nil
            phase = .result(draft)
        } catch is CancellationError {
            phase = .camera
        } catch let error as MealScanError where error == .quotaExceeded {
            presentFailure(
                message: ScanRetryPolicy.userMessage(for: error),
                image: image,
                error: error
            )
            onQuotaExhausted?()
        } catch {
            if !isAutomaticRetry, ScanRetryPolicy.shouldAutoRetry(error) {
                let delay = ScanRetryPolicy.jitterNanoseconds()
                try? await Task.sleep(nanoseconds: delay)
                await analyze(image: image, isAutomaticRetry: true)
                return
            }
            presentFailure(
                message: ScanRetryPolicy.userMessage(for: error),
                image: image,
                error: error
            )
        }
    }

    func retryFailedAnalysis() async {
        guard case .failed(_, let image?, true) = phase else {
            resetToCamera()
            return
        }
        analytics.track(.scanRetried)
        await analyze(image: image)
    }

    func resetToCamera() {
        slowAnalysisHint = nil
        analysisStartedAt = nil
        phase = .camera
        Task { await startCameraIfPossible() }
    }

    private func presentFailure(message: String, image: UIImage?, error: Error) {
        analytics.track(.scanFailed)
        slowAnalysisHint = nil
        phase = .failed(
            message: message,
            image: image,
            canRetryAnalysis: image != nil && ScanRetryPolicy.canRetryAnalysis(after: error)
        )
    }
}

struct ScannerFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: ScannerViewModel
    var onSaved: (() -> Void)?

    init(
        analysisService: (any MealAnalysisServing)? = nil,
        analytics: (any AnalyticsClient)? = nil,
        subscriptions: (any SubscriptionServicing)? = nil,
        aiScanQuota: LocalAIScanQuotaStore? = nil,
        onQuotaExhausted: (() -> Void)? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        // Environment isn’t available in init; RootTabView passes live services.
        let service = analysisService ?? MealAnalysisService(
            visionProvider: MockMealVisionProvider(),
            nutritionRepository: LocalNutritionRepository()
        )
        let analyticsClient = analytics ?? NoOpAnalyticsClient()
        _viewModel = State(
            initialValue: ScannerViewModel(
                analysisService: service,
                analytics: analyticsClient,
                subscriptions: subscriptions,
                aiScanQuota: aiScanQuota,
                onQuotaExhausted: onQuotaExhausted
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .task {
            // Prefer live environment analytics when presented from the app.
            await viewModel.onAppear()
        }
        .onChange(of: viewModel.pickerItem) { _, _ in
            Task { await viewModel.importPickerItem() }
        }
        .statusBarHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .camera:
            cameraPhase
        case .retake(let image):
            retakePhase(image)
        case .analyzing(let image, let stage):
            analyzingPhase(image, stage)
        case .result(let draft):
            MealResultView(draft: draft) {
                onSaved?()
                dismiss()
            } onCancel: {
                viewModel.resetToCamera()
            }
        case .failed(let message, let image, let canRetry):
            failedPhase(message: message, image: image, canRetryAnalysis: canRetry)
        }
    }

    private var cameraPhase: some View {
        ZStack {
            if viewModel.authorization == .authorized {
                CameraPreviewView(session: viewModel.cameraController.session)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: Spacing.space16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brandPrimary)
                    Text("Use your camera to scan a meal.")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if viewModel.authorization == .denied || viewModel.authorization == .restricted {
                        Text("Camera access is off.")
                            .foregroundStyle(.white.opacity(0.8))
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open Settings", destination: url)
                                .foregroundStyle(Color.brandPrimary)
                        }
                    } else {
                        PrimaryButton(title: "Enable camera") {
                            Task { await viewModel.requestCameraAndStart() }
                        }
                        .padding(.horizontal, Spacing.space32)
                    }
                }
                .padding()
            }

            VStack {
                topBar
                Spacer()
                Text("Fit the whole plate in frame")
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, Spacing.space12)
                bottomControls
            }
            .padding(.horizontal, Spacing.space16)
            .padding(.vertical, Spacing.space16)
        }
    }

    private var topBar: some View {
        HStack {
            glassIconButton(systemName: "xmark", label: "Close", action: { dismiss() })
            Spacer()
            Text("Meal scan")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.space12)
                .padding(.vertical, Spacing.space8)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            PhotosPicker(selection: $viewModel.pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Choose from Photos")
        }
    }

    private var bottomControls: some View {
        VStack(spacing: Spacing.space16) {
            if let message = viewModel.cameraController.errorMessage {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: Spacing.space24) {
                #if DEBUG
                Button("Sample") {
                    Task { await viewModel.useSampleFixture() }
                }
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .accessibilityLabel("Use sample meal")
                #endif

                Button {
                    Task { await viewModel.capture() }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(.white)
                            .frame(width: 62, height: 62)
                    }
                }
                .accessibilityLabel("Shutter")
                .disabled(viewModel.authorization != .authorized && viewModel.cameraController.errorMessage == nil)

                PhotosPicker(selection: $viewModel.pickerItem, matching: .images) {
                    Text("Library")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, Spacing.space24)
        }
    }

    private func retakePhase(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            HStack(spacing: Spacing.space12) {
                SecondaryButton(title: "Retake") {
                    viewModel.resetToCamera()
                }
                PrimaryButton(title: "Analyze meal") {
                    Task { await viewModel.analyze(image: image) }
                }
            }
            .padding(Spacing.space16)
            .background(Color.black.opacity(0.85))
        }
        .ignoresSafeArea()
    }

    private func analyzingPhase(_ image: UIImage, _ stage: MealAnalysisStage) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.25))

            VStack(alignment: .leading, spacing: Spacing.space12) {
                ProgressView()
                    .tint(Color.brandPrimary)
                Text(stageTitle(stage))
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Color.textPrimary)
                Text(viewModel.slowAnalysisHint ?? "Hang tight — mixed meals can take a moment.")
                    .font(Typography.supporting)
                    .foregroundStyle(Color.textSecondary)
                Button("Cancel") {
                    viewModel.resetToCamera()
                }
                .foregroundStyle(Color.textSecondary)
            }
            .padding(Spacing.space24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
            .padding(Spacing.space16)
        }
    }

    private func failedPhase(message: String, image: UIImage?, canRetryAnalysis: Bool) -> some View {
        VStack(spacing: Spacing.space16) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .padding(.horizontal, Spacing.space24)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: Spacing.space16)
            Text(message)
                .font(Typography.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.space24)
            if canRetryAnalysis {
                PrimaryButton(title: "Retry analysis") {
                    Task { await viewModel.retryFailedAnalysis() }
                }
                .padding(.horizontal, Spacing.space32)
            }
            SecondaryButton(title: "Retake photo") {
                viewModel.resetToCamera()
            }
            .padding(.horizontal, Spacing.space32)
            Button("Log manually") {
                viewModel.showManualAdd = true
            }
            .font(Typography.supporting.weight(.semibold))
            .foregroundStyle(Color.brandPrimary)
            PhotosPicker(selection: $viewModel.pickerItem, matching: .images) {
                Text("Choose from Photos")
                    .foregroundStyle(Color.brandPrimary)
            }
            Button("Close") { dismiss() }
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .sheet(isPresented: $viewModel.showManualAdd) {
            QuickAddSheet {
                onSaved?()
                dismiss()
            }
        }
    }

    private func glassIconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func stageTitle(_ stage: MealAnalysisStage) -> String {
        switch stage {
        case .preparingImage: "Looking at the meal…"
        case .identifyingFood: "Estimating portions…"
        case .resolvingNutrition: "Matching nutrition…"
        case .validating: "Building your log…"
        case .complete: "Done"
        }
    }
}
