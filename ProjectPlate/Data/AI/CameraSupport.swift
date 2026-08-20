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
