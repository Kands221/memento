import Foundation
import Observation
import SwiftData
import UIKit
import MementoCore

/// Owns the store, AI status and tagging coordinator for the app's lifetime.
@Observable
final class AppServices {
    let container: ModelContainer
    let ai: AIStatus
    let tagging: TaggingCoordinator
    let options: LaunchOptions
    /// On-device semantic index of the journal, used by Sol ("Sol remembers") and Discover.
    let journalIndex = JournalIndex()
    /// Cloud fallback (OpenRouter) for iPhones that can't run on-device AI; nil when the build has no key.
    let cloud = CloudAIConfig.load()
    /// Whether on-device Image Playground can paint entries ("Paint this day").
    private(set) var canPaint = false
    @ObservationIgnored private var journalSignature = 0

    init(options: LaunchOptions = .current) {
        self.options = options
        let defaults = UserDefaults.standard
        if options.uiTesting {
            for key in [SettingsKey.demoAIState, SettingsKey.demoTaggingEngine, SettingsKey.demoSolEngine,
                        SettingsKey.suggestTags, SettingsKey.solEnabled, SettingsKey.appearance, SettingsKey.reminderOn,
                        SettingsKey.cloudFallback, SolVoice.key, SolVoice.choiceKey] {
                defaults.removeObject(forKey: key)
            }
            defaults.set(options.skipOnboarding || options.seedSample, forKey: SettingsKey.hasOnboarded)
        } else if options.skipOnboarding {
            defaults.set(true, forKey: SettingsKey.hasOnboarded)
        }
        defaults.register(defaults: [SettingsKey.suggestTags: true, SettingsKey.solEnabled: true, SettingsKey.cloudFallback: true,
                                     SettingsKey.reminderMinutes: 1230, SettingsKey.reminderOn: false])
        do {
            container = try MementoStore.container(inMemory: options.uiTesting)
        } catch {
            fatalError("Couldn't open the journal store: \(error)")
        }
        let ai = AIStatus(override: options.aiState)
        self.ai = ai
        tagging = TaggingCoordinator(context: container.mainContext, engine: RuleTaggingEngine(),
                                     availability: { ai.availability },
                                     isEnabled: { UserDefaults.standard.bool(forKey: SettingsKey.suggestTags) })
        ai.isDemoEngine = { [unowned self] in taggingChoice == .demo }
        ai.isCloudEngine = { [unowned self] in usesCloud(taggingChoice) }
        ai.onChange = { [unowned self] in
            rebuildTaggingEngine()
            if ai.availability == .ready { tagging.resumePending() }
        }
        rebuildTaggingEngine()
        if options.seedSample { try? SampleJournal.load(into: container.mainContext, photo: SamplePhoto.data) }
    }

    var taggingChoice: EngineChoice {
        options.taggingEngine
            ?? EngineChoice(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoTaggingEngine) ?? "")
            ?? .onDevice
    }

    var solChoice: EngineChoice {
        options.solEngine
            ?? EngineChoice(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoSolEngine) ?? "")
            ?? .onDevice
    }

    /// Cloud AI runs when it's picked in Demo, or automatically when this iPhone can't run Apple's model at all.
    func usesCloud(_ choice: EngineChoice) -> Bool {
        guard cloud != nil else { return false }
        switch choice {
        case .cloud: return true
        case .demo: return false
        case .onDevice: return ai.live == .unsupported && UserDefaults.standard.bool(forKey: SettingsKey.cloudFallback)
        }
    }

    var taggingUsesCloud: Bool {
        _ = ai.revision
        return usesCloud(taggingChoice)
    }

    var solUsesCloud: Bool {
        _ = ai.revision
        return usesCloud(solChoice)
    }

    private var cloudClient: OpenRouterClient? { cloud.map { OpenRouterClient(apiKey: $0.apiKey) } }

    func rebuildTaggingEngine() {
        let base: any TaggingEngine
        if taggingChoice == .demo {
            base = RuleTaggingEngine()
        } else if usesCloud(taggingChoice), let cloud, let client = cloudClient {
            base = CloudTagger(client: client, model: cloud.taggingModel)
        } else {
            base = FoundationModelTagger()
        }
        tagging.engine = ai.demoState == .failing ? FailingOnceEngine(base: base) : base
    }

    func setEngine(tagging: EngineChoice? = nil, sol: EngineChoice? = nil) {
        if let tagging { UserDefaults.standard.set(tagging.rawValue, forKey: SettingsKey.demoTaggingEngine) }
        if let sol { UserDefaults.standard.set(sol.rawValue, forKey: SettingsKey.demoSolEngine) }
        rebuildTaggingEngine()
        ai.revision += 1
        if ai.availability == .ready { self.tagging.resumePending() }
    }

    func makeSolEngine() -> any SolEngine {
        if solChoice == .demo { return ScriptedSol() }
        if usesCloud(solChoice), let cloud, let client = cloudClient {
            return CloudSol(client: client, model: cloud.solModel, journal: journalIndex)
        }
        return FoundationModelSol(journal: journalIndex)
    }

    /// Rebuilds the journal index when entries or kept tags changed.
    func refreshJournal() async {
        let entries = (try? container.mainContext.fetch(FetchDescriptor<Entry>())) ?? []
        var hasher = Hasher()
        for e in entries {
            hasher.combine(e.id)
            hasher.combine(e.text)
            for t in e.keptTags { hasher.combine(t.label) }
        }
        let signature = hasher.finalize()
        guard signature != journalSignature else { return }
        journalSignature = signature
        await journalIndex.rebuild(from: entries.map(JournalDocument.init))
    }

    func checkPainting() async {
        let livePaint = ProcessInfo.processInfo.arguments.contains("-livePaint")
        canPaint = options.uiTesting && !livePaint ? false : await EntryArtist.isAvailable()
    }

    /// Whether Sol can run right now with the selected engine.
    var solAvailability: AIAvailability {
        _ = ai.revision
        return AIResolution.sol(live: ai.live, override: ai.demoState, demoSol: solChoice == .demo, cloud: usesCloud(solChoice))
    }
}

enum SamplePhoto {
    static var data: Data? { UIImage(named: "sample-ceramics")?.jpegData(compressionQuality: 0.85) }
}
