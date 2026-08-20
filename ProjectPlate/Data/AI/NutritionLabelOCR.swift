import Foundation
import UIKit
import Vision

protocol NutritionLabelOCRServing: Sendable {
    func recognizeLines(from imageData: Data) async throws -> [String]
}

struct VisionNutritionLabelOCR: NutritionLabelOCRServing {
    func recognizeLines(from imageData: Data) async throws -> [String] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw NutritionLabelOCRError.invalidImage
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum NutritionLabelOCRError: Error, LocalizedError, Sendable {
    case invalidImage
    case noText
    case unusableLabel

    var errorDescription: String? {
        switch self {
        case .invalidImage: "That image couldn’t be used."
        case .noText: "Couldn’t read text from this label."
        case .unusableLabel: "Couldn’t find calories or macros on this label."
        }
    }
}
