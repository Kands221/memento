import AVFoundation
import Foundation
import Observation
import MementoCore

/// A voice installed on this iPhone that Sol can speak with.
nonisolated struct SolVoiceOption: Identifiable, Hashable, Sendable {
    enum Tier: Int, Comparable {
        case classic, standard, enhanced, premium
        static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }
        var title: String {
            switch self {
            case .premium: "Premium"
            case .enhanced: "Enhanced"
            case .standard: "Standard"
            case .classic: "Classic synthesizer"
            }
        }
    }

    let id: String
    let name: String
    let accent: String
    let tier: Tier
    let isMale: Bool
}

/// Sol speaks aloud with the on-device speech synthesizer, warm and bright rather than flat.
/// Each sentence is spoken as soon as it finishes streaming. The writer can pick any installed voice.
@Observable
final class SolVoice: NSObject, AVSpeechSynthesizerDelegate {
    static let key = "solVoice"
    /// The writer's chosen voice identifier; empty means automatic.
    static let choiceKey = "solVoiceID"
    static let sample = "Hello, friend! I'm Sol. Shall we take today slowly, together? I'd love to hear how it went."

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

    /// Plays a short line in one voice, so the writer can choose by ear (works with the speaker off too).
    func preview(_ id: String?) {
        stop()
        speak(Self.sample, voice: id.flatMap(AVSpeechSynthesisVoice.init(identifier:)) ?? Self.automaticVoice())
    }

    private func speak(_ sentence: String, voice: AVSpeechSynthesisVoice? = nil) {
        let audio = AVAudioSession.sharedInstance()
        if audio.category != .playAndRecord {
            try? audio.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try? audio.setActive(true)
        let utterance = AVSpeechUtterance(string: sentence)
        let chosen = voice ?? Self.currentVoice()
        utterance.voice = chosen
        let delivery = Self.delivery(for: sentence, tier: chosen.map(Self.tier) ?? .standard)
        utterance.rate = delivery.rate
        utterance.pitchMultiplier = delivery.pitch
        utterance.postUtteranceDelay = 0.1
        synth.speak(utterance)
    }

    /// Bright and warm, not slow and low: natural speed, a slightly lifted pitch (more for basic voices,
    /// which sound flat otherwise), and a little extra lift on questions and exclamations.
    static func delivery(for sentence: String, tier: SolVoiceOption.Tier) -> (rate: Float, pitch: Float) {
        var rate = AVSpeechUtteranceDefaultSpeechRate * (tier >= .enhanced ? 1.0 : 0.98)
        var pitch: Float = switch tier {
        case .premium, .enhanced: 1.04
        case .standard: 1.1
        case .classic: 1.0
        }
        let end = sentence.trimmingCharacters(in: .whitespacesAndNewlines).last
        if end == "?" { pitch += 0.04 }
        if end == "!" { pitch += 0.05; rate += 0.02 }
        return (rate, pitch)
    }

    // MARK: Choosing a voice

    static func tier(_ v: AVSpeechSynthesisVoice) -> SolVoiceOption.Tier {
        if v.identifier.contains("eloquence") || v.identifier.contains("speech.synthesis.voice") { return .classic }
        switch v.quality {
        case .premium: return .premium
        case .enhanced: return .enhanced
        default: return .standard
        }
    }

    /// Voices for the writer's language, most natural first; novelty voices (bells, whispers…) are left out.
    static func options() -> [SolVoiceOption] {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let preferred = ["Evan", "Nathan", "Tom", "Aaron", "Arthur", "Jamie", "Oliver", "Daniel", "Lee"]
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) && !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
            .map { v in
                SolVoiceOption(id: v.identifier, name: v.name, accent: accent(v.language), tier: tier(v), isMale: v.gender == .male)
            }
            .sorted { a, b in
                if a.tier != b.tier { return a.tier > b.tier }
                if a.isMale != b.isMale { return a.isMale }    // Sol is an old gentleman
                let ra = preferred.firstIndex { a.name.contains($0) } ?? preferred.count
                let rb = preferred.firstIndex { b.name.contains($0) } ?? preferred.count
                if ra != rb { return ra < rb }
                let sa = a.id.contains("super-compact"), sb = b.id.contains("super-compact")
                if sa != sb { return !sa }
                return a.name < b.name
            }
    }

    static func automaticVoice() -> AVSpeechSynthesisVoice? {
        options().first.flatMap { AVSpeechSynthesisVoice(identifier: $0.id) } ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// The writer's pick if it's still installed, otherwise the best automatic choice.
    static func currentVoice() -> AVSpeechSynthesisVoice? {
        let choice = UserDefaults.standard.string(forKey: choiceKey) ?? ""
        return choice.isEmpty ? automaticVoice() : (AVSpeechSynthesisVoice(identifier: choice) ?? automaticVoice())
    }

    static func accent(_ language: String) -> String {
        switch language {
        case "en-GB": "British"
        case "en-US": "American"
        case "en-AU": "Australian"
        case "en-IE": "Irish"
        case "en-IN": "Indian"
        case "en-ZA": "South African"
        case "en-SC": "Scottish"
        default: Locale.current.localizedString(forIdentifier: language) ?? language
        }
    }

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
