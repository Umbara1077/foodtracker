import Foundation

/// Classifies meal-scan failures for auto-retry and recovery UI (PRODUCT_SPEC §46–47).
enum ScanRetryPolicy: Sendable {
    /// Transient provider/network errors get one automatic retry with jitter.
    static func shouldAutoRetry(_ error: Error) -> Bool {
        guard let scanError = error as? MealScanError else {
            // Unknown errors once — likely transient transport.
            return true
        }
        switch scanError {
        case .network, .providerUnavailable, .invalidStructuredResponse:
            return true
        case .permissionDenied, .invalidImage, .cancelled, .unauthorized, .quotaExceeded:
            return false
        }
    }

    static func canRetryAnalysis(after error: Error) -> Bool {
        guard let scanError = error as? MealScanError else { return true }
        switch scanError {
        case .quotaExceeded, .unauthorized, .permissionDenied, .invalidImage, .cancelled:
            return false
        case .network, .providerUnavailable, .invalidStructuredResponse:
            return true
        }
    }

    static func suggestsManualFallback(after error: Error) -> Bool {
        guard let scanError = error as? MealScanError else { return true }
        switch scanError {
        case .quotaExceeded, .network, .providerUnavailable, .invalidStructuredResponse, .unauthorized:
            return true
        case .permissionDenied, .invalidImage, .cancelled:
            return true
        }
    }

    static func userMessage(for error: Error, emptyPlate: Bool = false) -> String {
        if emptyPlate {
            return "I couldn’t confidently find food in this photo. Retake with the whole plate visible, or log it manually."
        }
        if let scanError = error as? MealScanError {
            return scanError.localizedDescription
        }
        return "Something went wrong analyzing this meal. You can retry or log it manually."
    }

    /// 200–600 ms jitter before the automatic second attempt.
    static func jitterNanoseconds(using generator: () -> UInt64 = { UInt64.random(in: 200_000_000...600_000_000) }) -> UInt64 {
        generator()
    }
}
