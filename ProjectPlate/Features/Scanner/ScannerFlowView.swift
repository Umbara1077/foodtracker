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
        case failed(String)
    }

    private let analysisService: any MealAnalysisServing
    private let cameraAuth: any CameraAuthorizing
    private let analytics: any AnalyticsClient

    var phase: Phase = .camera
    var authorization: CameraAuthorizationStatus = .notDetermined
    var cameraController = CameraSessionController()
    var isFlashOn = false
    var pickerItem: PhotosPickerItem?
    var analyzeImmediately = false

    init(
        analysisService: any MealAnalysisServing,
        cameraAuth: any CameraAuthorizing = SystemCameraAuthorization(),
        analytics: any AnalyticsClient
    ) {
        self.analysisService = analysisService
        self.cameraAuth = cameraAuth
        self.analytics = analytics
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
                phase = .failed(MealScanError.invalidImage.localizedDescription)
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if analyzeImmediately {
                await analyze(image: image)
            } else {
                phase = .retake(image)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func importPickerItem() async {
        guard let pickerItem else { return }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                phase = .failed(MealScanError.invalidImage.localizedDescription)
                return
            }
            phase = .retake(image)
        } catch {
            phase = .failed(error.localizedDescription)
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

    func analyze(image: UIImage) async {
        guard let jpeg = MealImageEncoder.jpegData(from: image) else {
            phase = .failed(MealScanError.invalidImage.localizedDescription)
            return
        }
        phase = .analyzing(image, .preparingImage)
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
                phase = .failed(draft.title.isEmpty
                    ? "I couldn’t confidently find food in this photo."
                    : "I couldn’t confidently find food in this photo. \(draft.confidence.userLabel).")
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            phase = .result(draft)
        } catch is CancellationError {
            phase = .camera
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func resetToCamera() {
        phase = .camera
        Task { await startCameraIfPossible() }
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
        onSaved: (() -> Void)? = nil
    ) {
        // Environment isn’t available in init; placeholders replaced in task if needed.
        let service = analysisService ?? MealAnalysisService(visionProvider: MockMealVisionProvider())
        let analyticsClient = analytics ?? NoOpAnalyticsClient()
        _viewModel = State(
            initialValue: ScannerViewModel(
                analysisService: service,
                analytics: analyticsClient
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
        case .failed(let message):
            failedPhase(message)
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
                Text("Hang tight — mixed meals can take a moment.")
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

    private func failedPhase(_ message: String) -> some View {
        VStack(spacing: Spacing.space16) {
            Spacer()
            Text(message)
                .font(Typography.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding()
            PrimaryButton(title: "Try again") { viewModel.resetToCamera() }
                .padding(.horizontal, Spacing.space32)
            PhotosPicker(selection: $viewModel.pickerItem, matching: .images) {
                Text("Choose from Photos")
                    .foregroundStyle(Color.brandPrimary)
            }
            Button("Close") { dismiss() }
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
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
