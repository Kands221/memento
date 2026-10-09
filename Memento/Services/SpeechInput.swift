import Foundation
import Observation

/// Speech to text on this iPhone: iOS 26 long-form transcription (SpeechAnalyzer) where supported,
/// classic on-device dictation otherwise (e.g. iPhone 12), so voice works everywhere Memento runs.
@Observable
final class SpeechInput {
    @ObservationIgnored private let live = LiveTranscriber()
    @ObservationIgnored private let classic = DictationService()
    private var useLive: Bool { LiveTranscriber.isSupported }

    var isAvailable: Bool { useLive ? live.isAvailable : classic.isAvailable }
    var isListening: Bool { useLive ? live.isListening : classic.isListening }
    var isPreparing: Bool { useLive && live.isPreparing }
    var errorText: String? { useLive ? live.errorText : classic.errorText }

    func start(onText: @escaping @MainActor (String) -> Void) async {
        if useLive { await live.start(onText: onText) } else { await classic.start(onText: onText) }
    }

    func stop() async {
        if useLive { await live.stop() } else { classic.stop() }
    }
}
