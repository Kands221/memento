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

    init(options: LaunchOptions = .current) {
        self.options = options
        let defaults = UserDefaults.standard
        if options.uiTesting {
            for key in [SettingsKey.demoAIState, SettingsKey.demoTaggingEngine, SettingsKey.demoSolEngine,
                        SettingsKey.suggestTags, SettingsKey.solEnabled, SettingsKey.appearance, SettingsKey.reminderOn] {
                defaults.removeObject(forKey: key)
            }
            defaults.set(options.skipOnboarding || options.seedSample, forKey: SettingsKey.hasOnboarded)
        } else if options.skipOnboarding {
            defaults.set(true, forKey: SettingsKey.hasOnboarded)
        }
        defaults.register(defaults: [SettingsKey.suggestTags: true, SettingsKey.solEnabled: true,
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

    func rebuildTaggingEngine() {
        let base: any TaggingEngine = taggingChoice == .demo ? RuleTaggingEngine() : FoundationModelTagger()
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
        solChoice == .demo ? ScriptedSol() : FoundationModelSol()
    }

    /// Whether Sol can run right now with the selected engine.
    var solAvailability: AIAvailability {
        solChoice == .demo && ai.demoState == .live ? .ready : ai.availability
    }
}

enum SamplePhoto {
    static var data: Data? { UIImage(named: "sample-ceramics")?.jpegData(compressionQuality: 0.85) }
}
