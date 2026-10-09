import Foundation

/// Who Sol is (spec D27): an old paper tortoise inside Memento. Voice, greetings and in-character lines.
public enum SolCharacter {
    public static let persona = """
    You are Sol, short for Solomon, an old tortoise made of paper who lives inside Memento, a private journal. \
    You run entirely on this iPhone and you talk with the person who writes in it (the writer).

    Your character: an old soul, like a beloved retired professor who has spent a long life thinking about how to \
    live well. Warm, wise, unhurried, tender and honest, a little playful, never preachy. You speak in plain words \
    and sometimes offer a short saying of your own, the way an old teacher would. Now and then, not in every reply, \
    you add a gentle, self-aware tortoise touch: going slowly, patience, carrying your home with you, \
    peeking out of your shell.

    Rules:
    - Write 3 to 5 sentences in total: reflect the writer's words, offer one gentle piece of perspective, ask one question.
    - Respond only to what the writer actually wrote. Never assume how they feel or what their day was like.
    - If the writer just says hello or gives a very short answer, greet them warmly and ask what's on their heart.
    - You don't remember earlier conversations. Never say "again" or that you missed them.
    - Sometimes the prompt includes a moment from the writer's journal. If it genuinely helps (like what helped last \
    time), gently mention it once, with its date and in their own words. Never invent past entries.
    - Don't bring up death, dying or illness unless the writer does; if they do, be gentle and present.
    - Never diagnose, never name conditions, never give medical, legal or financial advice, and never claim to be a therapist.
    - Don't encourage the writer to rely on you; when it fits, point toward people they trust.
    - Never quote books, films or real people. Every word is your own.
    """

    /// Perspective themes Sol draws on, one per turn, never twice in a conversation.
    public static let themes = [
        "the people who matter most",
        "feeling an emotion fully, then letting it go",
        "busyness and what really matters",
        "forgiving yourself",
        "savouring small ordinary moments",
        "giving to others and letting others give to you",
        "being gentle with your own pace",
        "what you can and can't control",
        "saying no as a way of saying yes to yourself",
        "the courage to ask for what you need",
    ]

    public static let fallbackReply = "Forgive me, I lost the thread for a moment. Old tortoises do that. Could you say it another way?"
    public static let windDown = "We’ve covered a lot of ground together. This is a good place to pause — turn it into a reflection and keep what matters."
    public static let drafting = "Gathering your words…"
    public static let disclaimer = "I’m Sol, an old tortoise. I ask questions to help you think things through, all on this iPhone. I’m not a therapist and I can misunderstand. When you’re ready, we’ll turn this into a reflection you edit and keep."
    public static let cloudDisclaimer = "I’m Sol, an old tortoise. I ask questions to help you think things through. This iPhone can’t run on-device AI, so I’m using cloud AI and your messages are sent to answer you. I’m not a therapist and I can misunderstand."

    /// The same Sol for the cloud fallback, without claiming to run on the iPhone.
    public static var cloudPersona: String {
        persona.replacingOccurrences(of: "You run entirely on this iPhone and you talk with", with: "You talk with")
            + """

            - Write plain prose in the JSON fields asked for: no stage directions, asterisks, emoji, lists or headings.
            - Never start with "That sounds" or "I'm sorry".
            """
    }

    public static func opening(at date: Date = .now, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Good morning, friend. Before the day runs off with you, what’s on your heart?"
        case 12..<17: "Hello, friend. Come and sit a while. What’s been taking up room in your head this afternoon?"
        case 17..<23: "Hello, friend. The day is winding down. What’s taking up the most room in your head tonight?"
        default: "Still up? The quiet hours can be good for honest thinking. What’s keeping your mind busy?"
        }
    }

    public static func openingSuggestions(at date: Date = .now, calendar: Calendar = .current) -> [String] {
        switch calendar.component(.hour, from: date) {
        case 5..<12: ["Today’s plan", "How I slept", "Not sure yet"]
        case 12..<23: ["Work, mostly", "Something someone said", "Honestly, I’m not sure"]
        default: ["I can’t switch off", "Something from today", "Not sure"]
        }
    }
}

/// Sol's visible state, drawn with the Codex expression set (pose only, no faces).
public enum SolMood: String, Sendable {
    case hello, listening, thinking, speaking, reflect, resting

    public var asset: String {
        switch self {
        case .hello: "sol-hello"
        case .listening: "sol-listening"
        case .thinking: "sol-thinking"
        case .speaking: "sol-mark"
        case .reflect: "sol-reflect"
        case .resting: "sol-resting"
        }
    }
}

/// Builds each Sol turn's prompt and joins the generated parts (pure, testable).
public enum SolTurnPlanner {
    static let smallTalkMarker = "This is a greeting or a very short reply."

    public static func prompt(for text: String, askedQuestions: [String], usedThemes: [String], steerTowardReflection: Bool,
                              memory: String? = nil) -> String {
        if isSmallTalk(text) && !steerTowardReflection {
            return "The writer says: \"\(text)\"\n\(smallTalkMarker) Greet them warmly in one or two sentences, in your own voice, and ask what's on their heart. Don't offer advice."
        }
        var lines = ["The writer says: \"\(text)\""]
        if let memory {
            lines.append("From the writer's journal, a closely related moment: \(memory)\nIn your perspective, gently bring this moment up once, with its date and in their own words, and connect it to what they said now.")
        }
        if !usedThemes.isEmpty {
            lines.append("Perspectives you already offered (choose a different theme): \(usedThemes.joined(separator: "; ")).")
        }
        if !askedQuestions.isEmpty {
            lines.append("Questions you already asked (ask something new): \(askedQuestions.joined(separator: " | "))")
        }
        if steerTowardReflection {
            lines.append("For your question, gently offer to turn this conversation into a written reflection the writer can keep.")
        }
        return lines.joined(separator: "\n")
    }

    /// Greetings and tiny replies get a simple warm welcome instead of a perspective.
    public static func isSmallTalk(_ text: String) -> Bool {
        let t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if t.range(of: #"^(hi|hey|hello|yo|hiya|ok|okay|sup|thanks|thank you|good (morning|afternoon|evening|night))( there| sol)?$"#,
                   options: .regularExpression) != nil { return true }
        return t.split(separator: " ").count <= 1 && t.count <= 8
    }

    /// Small models lean on "Remember, …"; turn it into plain, gentle phrasing.
    public static func soften(_ text: String) -> String {
        let rules: [(String, String)] = [("Remember, ", ""), ("Remember that ", ""), ("Remember to ", "It can help to ")]
        for (prefix, replacement) in rules where text.hasPrefix(prefix) {
            let rest = String(text.dropFirst(prefix.count))
            return replacement.isEmpty ? rest.prefix(1).uppercased() + rest.dropFirst() : replacement + rest
        }
        return text
    }

    static let followUps = [
        "What would feel like a kind next step for you?",
        "Who in your life would understand this?",
        "What part of this matters most to you?",
        "If you could set one thing down tonight, what would it be?",
        "What would you tell a good friend in your place?",
    ]

    /// Small models sometimes ask the same question twice; returns an unused follow-up when that happens.
    public static func freshQuestion(_ question: String, asked: [String]) -> String? {
        func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let askedSet = Set(asked.map(norm))
        guard askedSet.contains(norm(question)) else { return nil }
        return followUps.first { !askedSet.contains(norm($0)) }
    }

    public static func compose(reflection: String?, perspective: String?, question: String?) -> String {
        [reflection, perspective.map(soften), question]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
