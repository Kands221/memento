import Foundation
import MementoCore

enum EngineChoice: String, CaseIterable { case onDevice, demo, cloud }

/// Process arguments used by UI tests, screenshot runs and stage demos.
struct LaunchOptions {
    var uiTesting = false
    var seedSample = false
    var skipOnboarding = false
    var taggingEngine: EngineChoice?
    var solEngine: EngineChoice?
    var aiState: DemoAIState?
    /// Demo recordings: Sol animates even under UI-test automation.
    var demoRecording = false
    /// Demo recordings in the iOS Simulator, which has no working speech model: tapping the mic "hears" this text.
    var demoSpeech: String?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        func value(_ key: String) -> String? {
            guard let i = arguments.firstIndex(of: key), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        uiTesting = arguments.contains("-uiTesting")
        seedSample = arguments.contains("-seedSampleData")
        skipOnboarding = arguments.contains("-skipOnboarding")
        taggingEngine = value("-taggingEngine").flatMap(EngineChoice.init(rawValue:))
        solEngine = value("-solEngine").flatMap(EngineChoice.init(rawValue:))
        aiState = value("-aiState").flatMap(DemoAIState.init(rawValue:))
        demoRecording = arguments.contains("-demoRecording")
        demoSpeech = value("-demoSpeech")
    }
}
