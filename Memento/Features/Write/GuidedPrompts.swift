import Foundation
import MementoCore

/// Guided-reflection prompt categories (prototype PROMPTS).
enum PromptCategory: String, CaseIterable, Hashable {
    case gratitude, day, mind

    var title: String {
        switch self {
        case .gratitude: "Gratitude"
        case .day: "The day"
        case .mind: "On my mind"
        }
    }

    var prompts: [String] {
        switch self {
        case .gratitude: ["What are three small things you're grateful for today?", "Who made today a little easier?"]
        case .day: ["What happened today that you want to remember?", "What drained you today, and what gave something back?"]
        case .mind: ["What's taking up the most room in your head right now?", "What would you say if no one would ever read this?"]
        }
    }
}

/// "Use example" texts per mode (prototype EX).
enum EditorExamples {
    static func text(for mode: WritingMode) -> String {
        switch mode {
        case .dump: "too many deadlines. inbox at 214. forgot to reply to Jo. need groceries. I'm so overwhelmed I can't think straight. maybe a walk at lunch tomorrow"
        case .guided: "Theo made coffee before I woke up — grateful for that.\nThe rain stopped right as I left.\nPriya sent a voice note just to check in."
        case .photo: "Light through the kitchen window this morning. Felt calm for the first time this week."
        case .free, .sol: "Stayed late again to get the deck finished and I felt drained by the time I got home. Called my sister on the walk from the station and we laughed about Mum's new phone.\n\nStill hopeful the launch moves."
        }
    }
}
