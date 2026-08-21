import AVFoundation
import Foundation
import UIKit

enum CameraAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

protocol CameraAuthorizing: Sendable {
    func status() -> CameraAuthorizationStatus
    func requestAccess() async -> Bool
}

struct SystemCameraAuthorization: CameraAuthorizing {
    func status() -> CameraAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }

    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum CapturedMealImage: Sendable {
    case data(Data)

    var jpegData: Data {
        switch self {
        case .data(let data): data
        }
    }
}

enum MealImageEncoder {
    static func jpegData(
        from image: UIImage,
        maxDimension: CGFloat = 1400,
        quality: CGFloat = 0.78
    ) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    /// Re-encodes arbitrary image bytes as JPEG so EXIF/GPS and other container metadata are not forwarded.
    static func privacySafeJPEG(from data: Data, maxBytes: Int = 2_500_000) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        var dimension: CGFloat = 1400
        var quality: CGFloat = 0.78
        var output = jpegData(from: image, maxDimension: dimension, quality: quality)
        while let current = output, current.count > maxBytes, dimension > 640 || quality > 0.4 {
            if quality > 0.4 {
                quality -= 0.12
            } else {
                dimension = max(640, dimension * 0.75)
                quality = 0.7
            }
            output = jpegData(from: image, maxDimension: dimension, quality: quality)
        }
        guard let final = output, final.count <= maxBytes else { return output }
        return final
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
