import Testing
import Foundation
@testable import MementoCore

@Suite struct TextSegmentsTests {
    func mark(_ q: String, _ s: TagStatus = .kept) -> QuoteMark { QuoteMark(id: UUID(), kind: .feeling, status: s, quote: q) }

    @Test func splitsAroundMarksInTextOrder() {
        let text = "I felt drained after deadlines. A short walk helped."
        let segs = TextSegments.build(text: text, marks: [mark("A short walk helped"), mark("I felt drained")])
        #expect(segs.map(\.text).joined() == text)
        #expect(segs.compactMap(\.mark).map(\.quote) == ["I felt drained", "A short walk helped"])
        #expect(segs.first?.mark != nil)
    }

    @Test func skipsOverlappingMissingAndRemoved() {
        let text = "Back-to-back deadlines today."
        let segs = TextSegments.build(text: text, marks: [
            mark("Back-to-back deadlines"), mark("deadlines today"), mark("not there"), mark("today", .removed),
        ])
        #expect(segs.compactMap(\.mark).map(\.quote) == ["Back-to-back deadlines"])
        #expect(segs.map(\.text).joined() == text)
    }

    @Test func segmentsHandleEmoji() {
        let text = "Tea 🍵 at midnight 👩🏽‍💻 didn't help."
        let segs = TextSegments.build(text: text, marks: [mark("at midnight 👩🏽‍💻")])
        #expect(segs.map(\.text) == ["Tea 🍵 ", "at midnight 👩🏽‍💻", " didn't help."])
    }

    @Test func emptyTextAndNoMarks() {
        #expect(TextSegments.build(text: "", marks: [mark("x")]).isEmpty)
        #expect(TextSegments.build(text: "Plain.", marks: []).map(\.text) == ["Plain."])
    }
}
