import AVFoundation
import Foundation
import Speech

@MainActor
protocol VoiceMealCapturing: AnyObject {
    var isAvailable: Bool { get }
    var isListening: Bool { get }
    func requestAuthorization() async -> Bool
    func start(onPartial: @escaping (String) -> Void) throws
    func stop() -> String
}

@MainActor
final class SpeechVoiceMealCapturer: VoiceMealCapturing {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: .current)
    private(set) var isListening = false
    private var transcript = ""

    var isAvailable: Bool {
        recognizer?.isAvailable == true
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func start(onPartial: @escaping (String) -> Void) throws {
        stopEngine()
        transcript = ""
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceCaptureError.unavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    onPartial(self.transcript)
                }
                if error != nil || result?.isFinal == true {
                    self.stopEngine()
                }
            }
        }
    }

    func stop() -> String {
        request?.endAudio()
        stopEngine()
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        task?.cancel()
        task = nil
        request = nil
        isListening = false
    }
}

enum VoiceCaptureError: Error, LocalizedError, Sendable {
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable: "Voice entry isn’t available on this device."
        case .notAuthorized: "Microphone / speech access is off."
        }
    }
}
