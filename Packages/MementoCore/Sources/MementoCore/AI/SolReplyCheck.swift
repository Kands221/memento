import Foundation

/// The rules every Sol sentence must pass before the writer sees or hears it (plan §4).
/// Pure and deterministic, so it catches the slips a small on-device model makes, whatever the model.
public struct SolReplyCheck: Sendable {
    public enum Issue: String, Sendable, Hashable {
        case bannedOpener, assumedFeeling, clinicalWord, inventedMemory, quotesSomeone
        /// Sol speaking as if the writer's hard feelings were his own ("I feel guilty about not calling her").
        case speaksAsWriter
        /// A sentence Sol already said in this conversation.
        case repeatsItself
        /// Broken text, like "Feeling frustrated But remember".
        case malformed
    }

    /// Everything the writer said in this conversation, plus the journal moment Sol was given, lowercased.
    let ground: String
    /// The journal moment's date, like "sep 13", when Sol was given one.
    let memoryDate: String?
    /// Sentences Sol already said in this conversation, as word lists.
    let earlier: [[String]]

    public init(writerMessages: [String], memory: String? = nil, memoryDate: String? = nil, earlierReplies: [String] = []) {
        ground = (writerMessages + [memory ?? ""]).joined(separator: " ").lowercased()
        self.memoryDate = memoryDate?.lowercased()
        earlier = earlierReplies.flatMap { Self.sentences(in: $0, includeTrailing: true) }.map(Self.words).filter { $0.count >= 5 }
    }

    static func words(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter && $0 != "'" && $0 != "’" }.map(String.init)
    }

    /// Feelings Sol may only attribute to the writer if they (or their journal moment) named one from the same group.
    static let feelingGroups: [[String]] = [
        ["tired", "exhausted", "drained", "worn out", "weary", "burned out", "burnt out", "fatigued"],
        ["anxious", "anxiety", "worried", "worrying", "nervous", "uneasy", "on edge", "panicky", "panicked"],
        ["stressed", "stressful", "overwhelmed", "swamped", "pressured"],
        ["sad", "sadness", "heartbroken", "unhappy", "grief", "grieving", "sorrow"],
        ["lonely", "loneliness", "isolated", "alone"],
        ["angry", "anger", "furious", "frustrated", "frustration", "irritated", "annoyed", "resentful", "resentment"],
        ["scared", "afraid", "frightened", "fearful", "terrified"],
        ["guilty", "guilt", "ashamed", "shame"],
        ["hopeless", "despair", "helpless"],
    ]
    /// Losses that make naming grief or sadness a reflection rather than a guess.
    static let lossWords = ["miss", "died", "death", "passed away", "funeral", "anniversary", "lost", "grave"]
    static let clinical = ["depression", "depressed", "depressive", "disorder", "diagnos", "symptom", "trauma", "traumatic", "ptsd",
                           "adhd", "ocd", "bipolar", "panic attack", "burnout", "mental illness", "medication"]
    static let openers = ["that sounds", "it sounds like", "sounds like", "i'm sorry", "i’m sorry", "i am sorry", "remember,", "remember that"]
    static let months = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*"

    public func issues(in sentence: String, isOpening: Bool) -> [Issue] {
        let s = sentence.lowercased()
        var found: [Issue] = []
        if isOpening, Self.openers.contains(where: { s.hasPrefix($0) }) { found.append(.bannedOpener) }
        if assumesFeeling(s) { found.append(.assumedFeeling) }
        if Self.clinical.contains(where: { s.contains($0) && !ground.contains($0) }) { found.append(.clinicalWord) }
        if inventsMemory(s) { found.append(.inventedMemory) }
        if s.contains("once said") || s.contains("as the saying goes") || s.contains("as the old saying") { found.append(.quotesSomeone) }
        if speaksAsWriter(s) { found.append(.speaksAsWriter) }
        if repeats(s) { found.append(.repeatsItself) }
        if sentence.range(of: #"\b[a-z]+ (But|And|So|Remember|Yet)\b"#, options: .regularExpression) != nil { found.append(.malformed) }
        return found
    }

    private func repeats(_ s: String) -> Bool {
        let w = Self.words(s)
        guard w.count >= 5 else { return false }
        let set = Set(w)
        return earlier.contains { e in
            let other = Set(e)
            return Double(set.intersection(other).count) / Double(set.union(other).count) >= 0.7
        }
    }

    private func assumesFeeling(_ s: String) -> Bool {
        // Only sentences about the writer ("you…", "it's okay to feel…") can put a feeling on them; general wisdom is fine.
        let aboutThem = s.range(of: #"\byou(r|'re|’re|'ve|’ve|rself)?\b"#, options: .regularExpression) != nil
            || s.range(of: #"\b(it's|it’s|it is|its) (okay|ok|normal|natural|understandable|alright|all right|fine) to (feel|be)\b"#, options: .regularExpression) != nil
            || s.range(of: #"^feeling\b"#, options: .regularExpression) != nil
        guard aboutThem else { return false }
        for group in Self.feelingGroups {
            let named = group.contains { Self.has($0, in: ground) }
            if named { continue }
            if group.contains(where: { $0 == "sad" || $0 == "grief" }), Self.lossWords.contains(where: { ground.contains($0) }) { continue }
            for word in group where Self.has(word, in: s) {
                // "You're not alone" reassures; it doesn't assume.
                let negated = s.range(of: #"\b(not|never|no longer|isn't|aren't)\s+(so\s+|feeling\s+|be\s+)?\#(word)\b"#, options: .regularExpression) != nil
                if !negated { return true }
            }
        }
        return false
    }

    /// Sol talks about himself only in his own ways (noticing, wondering, gladness, a tortoise touch). Any other
    /// first-person sentence is the model slipping into the writer's shoes ("Maybe I should call her more"), and Sol
    /// can't act in the world ("Would you like me to call her?").
    private func speaksAsWriter(_ s: String) -> Bool {
        if s.range(of: #"\b(like|want|need) me to (call|text|talk to|tell|ask|send|go|meet|visit|email|book)\b"#, options: .regularExpression) != nil { return true }
        guard s.range(of: #"^((sometimes|maybe|honestly|lately|and|but|so|oh|well),? )?(i|i'm|i’m|i've|i’ve|i'd|i’d|i'll|i’ll|my)\b"#,
                      options: .regularExpression) != nil else { return false }
        if s.range(of: #"(tortoise|shell|my (long|many|old) (years|life|days)|old friend)"#, options: .regularExpression) != nil { return false }
        let solsOwn = #"^(i|i'm|i’m|i am|i've|i’ve|i have|i'd|i’d|i would|i'll|i’ll)\s+(really\s+|so\s+|always\s+|often\s+)?(glad|happy|here|listening|with you|curious|grateful|honou?red|proud of you|sorry|wonder|hear|think|believe|imagine|notice|see|can see|can hear|can tell|love|like|admire|appreciate|suspect|hope|wish|guess|learned|seen|found|noticed|watched|sense|feel for you|love to|like to|want to hear|want to know|be glad)\b"#
        return s.range(of: solsOwn, options: .regularExpression) == nil
    }

    private func inventsMemory(_ s: String) -> Bool {
        if let r = s.range(of: #"\b\#(Self.months)\.?\s+\d{1,2}\b"#, options: .regularExpression) {
            let mentioned = String(s[r])
            guard let memoryDate, let day = memoryDate.split(separator: " ").last,
                  mentioned.hasPrefix(String(memoryDate.prefix(3))), mentioned.hasSuffix(" " + day) || mentioned.hasSuffix(".\(day)") else { return true }
        }
        let pastEntry = #"\b(in your journal|in your entries|your entry|you wrote (on|last|back|before|earlier)|last (week|month|time) you (wrote|said|mentioned)|you (mentioned|told me) (before|earlier|last time)|when we last (talked|spoke))\b"#
        if memoryDate == nil, s.range(of: pastEntry, options: .regularExpression) != nil { return true }
        return false
    }

    static func has(_ word: String, in text: String) -> Bool {
        text.range(of: #"\b\#(NSRegularExpression.escapedPattern(for: word))\b"#, options: .regularExpression) != nil
    }

    /// Safe, meaning-preserving fixes: Sol has no memory of earlier chats, so "again" and "welcome back" go
    /// unless the writer used them.
    public static func tidy(_ sentence: String, writerSaid: String) -> String {
        var s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let said = writerSaid.lowercased()
        if !said.contains("again") {
            for pattern in [#"\b(see|hear from|talk to|talk with|have|having) you again\b"#, #"\b(hello|hi|hey) again\b"#] {
                if let r = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    s.replaceSubrange(r, with: s[r].replacingOccurrences(of: " again", with: "", options: .caseInsensitive))
                }
            }
        }
        if !said.contains("back"), let r = s.range(of: #"\bwelcome back\b"#, options: [.regularExpression, .caseInsensitive]) {
            s.replaceSubrange(r, with: s[r].prefix(1) == "W" ? "Welcome" : "welcome")
        }
        s = s.replacingOccurrences(of: #"\s+([,.!?])"#, with: "$1", options: .regularExpression)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// Splits text into sentences. The last piece counts only when `includeTrailing` (its field has finished streaming).
    public static func sentences(in text: String, includeTrailing: Bool) -> [String] {
        var out: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            guard ".!?…".contains(ch) else { continue }
            let next = i + 1 < chars.count ? chars[i + 1] : nil
            if let next, next.isWhitespace || next == "\"" || next == "”" {
                append(&out, current)
                current = ""
            } else if next == nil && includeTrailing {
                append(&out, current)
                current = ""
            }
        }
        if includeTrailing { append(&out, current) }
        return out
    }

    private static func append(_ out: inout [String], _ piece: String) {
        let t = piece.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"”")))
        if !t.isEmpty { out.append(t) }
    }
}
