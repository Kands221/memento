import Foundation
import SwiftData

/// The prototype's sample journal, loaded from You → Demo (spec D10).
public enum SampleJournal {
    struct Seed {
        let n: Int
        let daysAgo: Int, hour: Int, minute: Int
        let notebook: String
        let mode: WritingMode
        var prompt: String? = nil
        var hasPhoto = false
        let text: String
        let tags: [(String, TagKind, String?, TagStatus)]
    }

    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "4D454D00-0000-4000-8000-%012d", n))! }
    public static var entryIDs: [UUID] { seeds.map { id($0.n) } }

    static let seeds: [Seed] = [
        Seed(n: 8, daysAgo: 1, hour: 23, minute: 52, notebook: "daily", mode: .free,
             text: "Couldn't sleep until almost two. Kept replaying the conversation with Dana about moving the launch date, and everything I should have said.\n\nMade tea at midnight, which didn't help. Writing out a list of what's actually due this week did.",
             tags: [("Poor sleep", .situation, "Couldn't sleep until almost two", .kept), ("Restless", .feeling, "Kept replaying", .suggested),
                    ("Conflict", .situation, "the conversation with Dana about moving the launch date", .kept),
                    ("Writing it down", .helped, "Writing out a list of what's actually due this week did", .kept)]),
        Seed(n: 7, daysAgo: 2, hour: 22, minute: 5, notebook: "daily", mode: .free,
             text: "Finished the book Priya lent me — read the last chapter in the bath. Nothing much happened today and honestly that felt like a gift.",
             tags: [("Calm", .feeling, "that felt like a gift", .kept), ("Reading", .helped, "read the last chapter in the bath", .kept)]),
        Seed(n: 6, daysAgo: 3, hour: 19, minute: 40, notebook: "work", mode: .dump,
             text: "Deadlines everywhere. Sprint review moved up to Thursday, the deck isn't done, and I said yes to mentoring the new hire because apparently I can't say no. Overwhelmed is the word.\n\nTook the long way home through the park and felt like a person again.",
             tags: [("Work deadlines", .situation, "Deadlines everywhere", .kept), ("Boundaries", .situation, "apparently I can't say no", .suggested),
                    ("Overwhelmed", .feeling, "Overwhelmed is the word", .kept), ("Walking helped", .helped, "Took the long way home through the park", .kept)]),
        Seed(n: 5, daysAgo: 5, hour: 9, minute: 15, notebook: "grat", mode: .guided, prompt: "What are three small things you're grateful for today?",
             text: "Sunday pancakes with Theo, even though we burned the first batch.\nTomatoes from the market that actually taste like tomatoes.\nMum calling just to say hi.",
             tags: [("Grateful", .feeling, "Sunday pancakes with Theo", .kept), ("Family", .topic, "Mum calling just to say hi", .kept)]),
        Seed(n: 4, daysAgo: 10, hour: 20, minute: 30, notebook: "daily", mode: .photo, hasPhoto: true,
             text: "My first bowl is lopsided and I love it. Two hours where I didn't check my phone once.",
             tags: [("Absorbed", .feeling, "Two hours where I didn't check my phone once", .kept),
                    ("Making things", .helped, "My first bowl is lopsided and I love it", .kept), ("Creativity", .topic, nil, .kept)]),
        Seed(n: 3, daysAgo: 15, hour: 23, minute: 10, notebook: "work", mode: .free,
             text: "Third late night this week and I'm completely drained. Snapped at Theo over nothing and had to apologise.\n\nWalked to the corner shop just to get out of the flat, and it took the edge off.",
             tags: [("Work deadlines", .situation, "Third late night this week", .kept), ("Drained", .feeling, "I'm completely drained", .kept),
                    ("Conflict", .situation, "Snapped at Theo over nothing", .kept), ("Walking helped", .helped, "Walked to the corner shop just to get out of the flat", .kept)]),
        Seed(n: 2, daysAgo: 22, hour: 21, minute: 48, notebook: "refl", mode: .sol,
             text: "On saying no. I keep agreeing to things before I've checked whether I have room for them. Tonight I noticed it's less about being helpful and more about not wanting to disappoint anyone.\n\nNext time, I'll start with “let me get back to you.”",
             tags: [("Boundaries", .situation, "I keep agreeing to things before I've checked whether I have room for them", .kept),
                    ("Hopeful", .feeling, "Next time, I'll start with “let me get back to you.”", .kept)]),
        Seed(n: 1, daysAgo: 27, hour: 20, minute: 2, notebook: "daily", mode: .free,
             text: "Long walk with Priya after work. Told her about my doubts about the job and she didn't try to fix anything, just listened. Felt lighter on the way home.",
             tags: [("Walking helped", .helped, "Long walk with Priya after work", .kept), ("Talking to a friend", .helped, "she didn't try to fix anything, just listened", .kept),
                    ("Lighter", .feeling, "Felt lighter on the way home", .kept), ("Work", .topic, "my doubts about the job", .kept)]),
    ]

    @MainActor @discardableResult
    public static func load(into context: ModelContext, today: Date = .now, calendar: Calendar = .current, photo: Data? = nil) throws -> Int {
        let existing = Set(try context.fetch(FetchDescriptor<Entry>()).map(\.id))
        var inserted = 0
        for seed in seeds where !existing.contains(id(seed.n)) {
            let day = calendar.date(byAdding: .day, value: -seed.daysAgo, to: calendar.startOfDay(for: today))!
            let date = calendar.date(bySettingHour: seed.hour, minute: seed.minute, second: 0, of: day)!
            let entry = Entry(id: id(seed.n), createdAt: date, notebookID: seed.notebook, mode: seed.mode,
                              prompt: seed.prompt, text: seed.text, photoData: seed.hasPhoto ? photo : nil, tagging: .done)
            context.insert(entry)
            for t in seed.tags { entry.addTag(label: t.0, kind: t.1, quote: t.2, status: t.3) }
            inserted += 1
        }
        try context.save()
        return inserted
    }

    /// Demo → Clear journal: deletes every entry (and, by cascade, every tag).
    @MainActor
    public static func clear(from context: ModelContext) throws {
        // Per-object deletes (not batch): they include unsaved inserts and cascade to tags.
        for entry in try context.fetch(FetchDescriptor<Entry>()) { context.delete(entry) }
        try context.save()
    }
}
