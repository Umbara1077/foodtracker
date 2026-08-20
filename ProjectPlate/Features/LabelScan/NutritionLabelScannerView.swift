import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class NutritionLabelScannerViewModel {
    enum Phase: Equatable {
        case pick
        case reading
        case review(NutritionFood)
        case failed(String)
    }

    private let ocr: any NutritionLabelOCRServing
    var phase: Phase = .pick
    var pickerItem: PhotosPickerItem?

    init(ocr: any NutritionLabelOCRServing = VisionNutritionLabelOCR()) {
        self.ocr = ocr
    }

    func importPickerItem() async {
        guard let pickerItem else { return }
        phase = .reading
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                phase = .failed(NutritionLabelOCRError.invalidImage.localizedDescription)
                return
            }
            try await analyze(imageData: data)
        } catch {
            phase = .failed(error.localizedDescription)
        }
        self.pickerItem = nil
    }

    func analyze(imageData: Data) async throws {
        let lines = try await ocr.recognizeLines(from: imageData)
        guard !lines.isEmpty else {
            phase = .failed(NutritionLabelOCRError.noText.localizedDescription)
            return
        }
        let draft = NutritionLabelParser.parse(lines: lines)
        guard let food = draft.asNutritionFood() else {
            phase = .failed(NutritionLabelOCRError.unusableLabel.localizedDescription)
            return
        }
        phase = .review(food)
    }

    func reset() {
        phase = .pick
    }
}

struct NutritionLabelScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NutritionLabelScannerViewModel()
    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .pick:
                    pickPhase
                case .reading:
                    ProgressView("Reading label…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .review(let food):
                    FoodEditorSheet(food: food, inputMethod: .labelScan) {
                        onSaved?()
                        dismiss()
                    }
                case .failed(let message):
                    failedPhase(message)
                }
            }
            .navigationTitle("Scan label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: viewModel.pickerItem) { _, _ in
                Task { await viewModel.importPickerItem() }
            }
        }
    }

    private var pickPhase: some View {
        VStack(spacing: Spacing.space20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)
            Text("Photograph a Nutrition Facts label")
                .font(Typography.sectionHeading)
                .multilineTextAlignment(.center)
            Text("We’ll read calories and macros, then let you confirm the portion.")
                .font(Typography.supporting)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            PhotosPicker(selection: $viewModel.pickerItem, matching: .images) {
                Text("Choose photo")
                    .font(Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.space16)
                    .foregroundStyle(Color.brandInk)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
            .padding(.horizontal, Spacing.space32)
            Spacer()
        }
        .padding(Spacing.space24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }

    private func failedPhase(_ message: String) -> some View {
        VStack(spacing: Spacing.space16) {
            Text(message)
                .font(Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textPrimary)
            PrimaryButton(title: "Try again") {
                viewModel.reset()
            }
            .padding(.horizontal, Spacing.space32)
            Button("Close") { dismiss() }
                .foregroundStyle(Color.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }
}
