import Foundation
import Observation

/// Speech to text on this iPhone: iOS 26 long-form transcription (SpeechAnalyzer) where supported,
/// classic on-device dictation otherwise (e.g. iPhone 12), so voice works everywhere Memento runs.
@Observable
final class SpeechInput {
    @ObservationIgnored private let live = LiveTranscriber()
    @ObservationIgnored private let classic = DictationService()
    private var useLive: Bool { LiveTranscriber.isSupported }
    /// Demo recordings only (`-demoSpeech`): the iOS Simulator has no working speech model, so the mic
    /// "hears" a scripted line word by word, the way live dictation fills the field on an iPhone.
    @ObservationIgnored private let demoLines = LaunchOptions.current.demoSpeech?.components(separatedBy: " | ")
    @ObservationIgnored private var demoTurn = 0
    private var demoLine: String? { demoLines.map { $0[min(demoTurn, $0.count - 1)] } }
    private var demoListening = false
    @ObservationIgnored private var demoTask: Task<Void, Never>?

    var isAvailable: Bool { demoLine != nil || (useLive ? live.isAvailable : classic.isAvailable) }
    var isListening: Bool { demoLine != nil ? demoListening : (useLive ? live.isListening : classic.isListening) }
    var isPreparing: Bool { demoLine == nil && useLive && live.isPreparing }
    var errorText: String? { demoLine != nil ? nil : (useLive ? live.errorText : classic.errorText) }

    func start(onText: @escaping @MainActor (String) -> Void) async {
        if let demoLine {
            demoListening = true
            demoTurn += 1
            let words = demoLine.split(separator: " ").map(String.init)
            demoTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                for i in words.indices where !Task.isCancelled {
                    onText(words[...i].joined(separator: " "))
                    try? await Task.sleep(for: .milliseconds(230))
                }
            }
            return
        }
        if useLive { await live.start(onText: onText) } else { await classic.start(onText: onText) }
    }

    func stop() async {
        if demoLine != nil {
            _ = await demoTask?.value
            demoListening = false
            return
        }
        if useLive { await live.stop() } else { classic.stop() }
    }
}
