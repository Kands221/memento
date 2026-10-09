import AVFoundation
import Foundation
import Observation
import MementoCore

/// Sol speaks aloud with the on-device speech synthesizer: slow and warm, like an old tortoise.
/// Each sentence is spoken as soon as it finishes streaming.
@Observable
final class SolVoice: NSObject, AVSpeechSynthesizerDelegate {
    static let key = "solVoice"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.key)
            if !isEnabled { stop() }
        }
    }
    private(set) var isSpeaking = false
    /// Increments on every spoken word, so Sol's avatar can nod along.
    private(set) var wordTick = 0
    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private var chunker = SpeechChunker()

    override init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.key)
        super.init()
        synth.delegate = self
    }

    /// Feed the growing reply text; whole sentences are spoken as they complete.
    func feed(_ text: String, final: Bool) {
        guard isEnabled else { return }
        for sentence in chunker.newSentences(in: text, final: final) { speak(sentence) }
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        chunker = SpeechChunker()
        isSpeaking = false
    }

    private func speak(_ sentence: String) {
        let audio = AVAudioSession.sharedInstance()
        if audio.category != .playAndRecord {
            try? audio.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try? audio.setActive(true)
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = Self.voice
        utterance.rate = 0.43
        utterance.pitchMultiplier = 0.9
        utterance.postUtteranceDelay = 0.15
        synth.speak(utterance)
    }

    /// The highest-quality voice for the writer's language, preferring warm, older-sounding ones.
    static let voice: AVSpeechSynthesisVoice? = {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language) }
        let best = voices.map(\.quality.rawValue).max() ?? 0
        let top = voices.filter { $0.quality.rawValue == best }
        let preferred = ["Daniel", "Arthur", "Oliver", "Aaron", "Fred", "Gordon"]
        return top.first { v in preferred.contains { v.name.contains($0) } } ?? top.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = self.synth.isSpeaking }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        Task { @MainActor in self.wordTick += 1 }
    }
}
