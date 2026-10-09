import AVFoundation
import Foundation
import Observation
import Speech

/// Long-form, on-device speech-to-text with iOS 26 SpeechAnalyzer + SpeechTranscriber.
/// Shows live (volatile) words as you speak and settles them into final text. Audio is never stored.
@Observable
final class LiveTranscriber {
    private(set) var isListening = false
    private(set) var isPreparing = false
    private(set) var errorText: String?
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var feed: AsyncStream<AnalyzerInput>.Continuation?
    @ObservationIgnored private var results: Task<Void, Never>?
    @ObservationIgnored private var session = UUID()

    static var isSupported: Bool { SpeechTranscriber.isAvailable }
    var isAvailable: Bool { Self.isSupported }

    func start(onText: @escaping @MainActor (String) -> Void) async {
        guard Self.isSupported, !isListening, !isPreparing else { return }
        errorText = nil
        guard await AVAudioApplication.requestRecordPermission() else {
            errorText = "Allow the microphone for Memento in Settings to talk."
            return
        }
        isPreparing = true
        defer { isPreparing = false }
        do {
            let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) ?? Locale(identifier: "en-US")
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            // One-time, on-device language asset.
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                errorText = "Speech isn’t available right now."
                return
            }
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
            try audio.setActive(true, options: .notifyOthersOnDeactivation)
            let engine = AVAudioEngine()
            let inputFormat = engine.inputNode.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                errorText = "No microphone input is available right now."
                return
            }
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            Self.installTap(on: engine.inputNode, from: inputFormat, to: format, feeding: continuation)
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            engine.prepare()
            try engine.start()
            try await analyzer.start(inputSequence: stream)
            self.engine = engine
            self.analyzer = analyzer
            self.feed = continuation
            let current = UUID()
            session = current
            isListening = true
            results = Task { [weak self] in
                var finalized = ""
                do {
                    for try await result in transcriber.results {
                        let piece = String(result.text.characters)
                        let shown: String
                        if result.isFinal {
                            finalized += piece
                            shown = finalized
                        } else {
                            shown = finalized + piece
                        }
                        guard let self, self.session == current else { return }
                        onText(shown.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } catch {
                    // The stream ends with an error when cancelled; nothing to show.
                }
            }
        } catch {
            errorText = "Couldn’t start listening."
            await stop()
        }
    }

    /// Stops the microphone, lets the last words settle, then ignores any later callbacks.
    func stop() async {
        guard isListening || engine != nil else { return }
        isListening = false
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        feed?.finish()
        feed = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        _ = await results?.value
        results = nil
        session = UUID()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Runs on the audio thread: convert mic buffers into the analyzer's format.
    nonisolated private static func installTap(on node: AVAudioInputNode, from input: AVAudioFormat, to output: AVAudioFormat,
                                               feeding continuation: AsyncStream<AnalyzerInput>.Continuation) {
        nonisolated(unsafe) let converter = AVAudioConverter(from: input, to: output)
        node.installTap(onBus: 0, bufferSize: 4096, format: input) { buffer, _ in
            guard let converter else { return }
            let ratio = output.sampleRate / input.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let converted = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return }
            final class Once: @unchecked Sendable { var done = false }
            let once = Once()
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, status in
                if once.done {
                    status.pointee = .noDataNow
                    return nil
                }
                once.done = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil, converted.frameLength > 0 { continuation.yield(AnalyzerInput(buffer: converted)) }
        }
    }
}
