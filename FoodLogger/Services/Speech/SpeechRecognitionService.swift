import Foundation
import Speech
import AVFoundation

@Observable
@MainActor
final class SpeechRecognitionService {
    var transcript: String = ""
    var isRecording: Bool = false
    var isAvailable: Bool = false
    var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    init() {
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    /// Request both microphone and speech recognition permissions. Returns true if both granted.
    func requestPermission() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition permission denied. Enable it in Settings."
            return false
        }

        let audioStatus: Bool
        if #available(iOS 17.0, *) {
            audioStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            audioStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard audioStatus else {
            errorMessage = "Microphone permission denied. Enable it in Settings."
            return false
        }

        isAvailable = true
        return true
    }

    func startRecording() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.notAvailable
        }

        // Stop any existing task
        stopRecording()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        audioEngine = engine
        recognitionRequest = request
        isRecording = true
        errorMessage = nil
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum SpeechError: LocalizedError {
    case notAvailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Speech recognition is not available on this device."
        case .permissionDenied: return "Speech recognition permission was denied."
        }
    }
}
