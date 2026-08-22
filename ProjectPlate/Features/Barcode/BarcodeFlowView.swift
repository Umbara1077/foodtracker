import AVFoundation
import SwiftUI

@MainActor
final class BarcodeFlowViewModel: ObservableObject {
    enum Phase: Equatable {
        case scanning
        case lookingUp(String)
        case notFound(String)
        case failed(String)
    }

    private let nutritionRepository: any NutritionRepository
    private let cameraAuth: any CameraAuthorizing
    private let analytics: any AnalyticsClient

    @Published var phase: Phase = .scanning
    @Published var authorization: CameraAuthorizationStatus = .notDetermined
    @Published var capture = BarcodeCaptureController()
    @Published var manualCode = ""
    @Published var selectedFood: NutritionFood?
    private var lastHandledCode: String?
    private var lookupTask: Task<Void, Never>?

    init(
        nutritionRepository: any NutritionRepository,
        cameraAuth: any CameraAuthorizing = SystemCameraAuthorization(),
        analytics: any AnalyticsClient
    ) {
        self.nutritionRepository = nutritionRepository
        self.cameraAuth = cameraAuth
        self.analytics = analytics
        self.authorization = cameraAuth.status()
    }

    func onAppear() async {
        analytics.track(.barcodeOpened)
        authorization = cameraAuth.status()
        capture.onCode = { [weak self] code in
            Task { @MainActor in
                await self?.handleScanned(code)
            }
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
            try capture.configure()
            capture.start()
        } catch {
            capture.errorMessage = "Camera unavailable. Enter a barcode manually."
        }
    }

    func handleScanned(_ raw: String) async {
        let code = BarcodeNormalizer.normalize(raw)
        guard BarcodeNormalizer.isPlausible(code) else { return }
        guard code != lastHandledCode else { return }
        lastHandledCode = code
        await lookup(code)
    }

    func submitManual() async {
        let code = BarcodeNormalizer.normalize(manualCode)
        guard BarcodeNormalizer.isPlausible(code) else {
            phase = .failed("Enter a valid UPC/EAN barcode (8–14 digits).")
            return
        }
        lastHandledCode = code
        await lookup(code)
    }

    func useSample(_ code: String) async {
        manualCode = code
        await handleScanned(code)
    }

    func reset() {
        lookupTask?.cancel()
        phase = .scanning
        lastHandledCode = nil
        selectedFood = nil
        Task { await startCameraIfPossible() }
    }

    func clearSelectedProduct() {
        selectedFood = nil
        lastHandledCode = nil
        Task { await startCameraIfPossible() }
    }

    private func lookup(_ code: String) async {
        lookupTask?.cancel()
        capture.stop()
        phase = .lookingUp(code)
        lookupTask = Task {
            do {
                if let food = try await nutritionRepository.lookupBarcode(code) {
                    guard !Task.isCancelled else { return }
                    PlateHaptics.play(.scanSuccess)
                    selectedFood = food
                    phase = .scanning
                } else {
                    guard !Task.isCancelled else { return }
                    phase = .notFound(code)
                }
            } catch {
                guard !Task.isCancelled else { return }
                PlateHaptics.play(.warning)
                phase = .failed(error.localizedDescription)
            }
        }
        await lookupTask?.value
    }
}

struct BarcodeFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: BarcodeFlowViewModel?
    @Published var onSaved: (() -> Void)?

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel?.capture.stop()
                        dismiss()
                    }
                }
            }
            .sheet(item: Binding(
                get: { viewModel?.selectedFood },
                set: { newValue in
                    if newValue == nil {
                        viewModel?.clearSelectedProduct()
                    } else {
                        viewModel?.selectedFood = newValue
                    }
                }
            )) { food in
                FoodEditorSheet(food: food, inputMethod: .barcode) {
                    onSaved?()
                    dismiss()
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = BarcodeFlowViewModel(
                    nutritionRepository: environment.nutritionRepository,
                    analytics: environment.analytics
                )
                viewModel = vm
                await vm.onAppear()
            }
        }
        .onDisappear {
            viewModel?.capture.stop()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: BarcodeFlowViewModel) -> some View {
        switch viewModel.phase {
        case .scanning:
            scanning(viewModel)
        case .lookingUp(let code):
            VStack(spacing: Spacing.space16) {
                ProgressView("Looking up \(code)…")
                Text("Checking local cache, then Open Food Facts if needed.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        case .notFound(let code):
            PlateUnavailableView {
                Label("No product found", systemImage: "barcode.viewfinder")
            } description: {
                Text("No nutrition data for \(code). Try Search foods or Quick add — we never invent values from barcode digits alone.")
            } actions: {
                Button("Scan again") { viewModel.reset() }
                Button("Close") { dismiss() }
            }
        case .failed(let message):
            PlateUnavailableView {
                Label("Lookup failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { viewModel.reset() }
            }
        }
    }

    private func scanning(_ viewModel: BarcodeFlowViewModel) -> some View {
        @ObservedObject var viewModel = viewModel
        return ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.authorization == .authorized {
                BarcodePreview(session: viewModel.capture.session)
                    .ignoresSafeArea()
            }

            VStack {
                Spacer()
                VStack(spacing: Spacing.space12) {
                    if viewModel.authorization != .authorized {
                        Text(viewModel.authorization == .notDetermined
                             ? "Camera access is needed to scan barcodes."
                             : "Camera is off. Enter a barcode below, or enable camera in Settings.")
                            .font(Typography.supporting)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        if viewModel.authorization == .notDetermined || viewModel.authorization == .denied {
                            Button("Enable camera") {
                                Task { await viewModel.requestCameraAndStart() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Text("Align the barcode in the frame")
                            .font(Typography.supporting.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    if let message = viewModel.capture.errorMessage {
                        Text(message)
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    HStack {
                        TextField("Enter barcode", text: $viewModel.manualCode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button("Lookup") {
                            Task { await viewModel.submitManual() }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    #if DEBUG
                    VStack(alignment: .leading, spacing: Spacing.space8) {
                        Text("Simulator samples")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        ForEach(BundledBarcodeCatalog.entries.prefix(3), id: \.barcode) { entry in
                            Button("\(entry.barcode) · \(entry.food.name)") {
                                Task { await viewModel.useSample(entry.barcode) }
                            }
                            .font(Typography.caption)
                            .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    #endif
                }
                .padding(Spacing.space16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .padding(Spacing.space16)
            }
        }
    }
}

private struct BarcodePreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
