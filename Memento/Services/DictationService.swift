import AVFoundation
import Foundation
import Observation
import Speech

/// On-device speech-to-text for the editor's Speak button (spec D16). Audio is never stored.
@Observable
final class DictationService {
    private(set) var isListening = false
    private(set) var errorText: String?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Identifies the current dictation; late callbacks from a stopped one are ignored.
    @ObservationIgnored private var session = UUID()

    /// Only offered when recognition can run entirely on this iPhone.
    var isAvailable: Bool { recognizer?.supportsOnDeviceRecognition == true }

    func start(onText: @escaping @MainActor (String) -> Void) async {
        guard let recognizer, recognizer.supportsOnDeviceRecognition, !isListening else { return }
        errorText = nil
        let speechOK = await Self.requestSpeechAuthorization()
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard speechOK, micOK else {
            errorText = "Allow Microphone and Speech Recognition for Memento in Settings to dictate."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let engine = AVAudioEngine()
            let format = engine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                errorText = "No microphone input is available right now."
                try? session.setActive(false)
                return
            }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            Self.installTap(on: engine.inputNode, feeding: request)
            engine.prepare()
            try engine.start()
            self.engine = engine
            self.request = request
            isListening = true
            let current = UUID()
            self.session = current
            task = Self.recognize(with: recognizer, request: request) { [weak self] text, finished in
                Task { @MainActor in
                    guard let self, self.isListening, self.session == current else { return }
                    if let text { onText(text) }
                    if finished { self.stop() }
                }
            }
        } catch {
            errorText = "Couldn’t start dictation."
            stop()
        }
    }

    func stop() {
        session = UUID()
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        engine = nil
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Callbacks below run on audio/recognition queues, so they must not inherit MainActor isolation.

    nonisolated private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    nonisolated private static func installTap(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        nonisolated(unsafe) let request = request
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func recognize(with recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest,
                                              handler: @escaping @Sendable (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, error != nil || result?.isFinal == true)
        }
    }
}
