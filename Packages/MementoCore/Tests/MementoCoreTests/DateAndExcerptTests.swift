import Testing
import Foundation
@testable import MementoCore

@Suite struct DateAndExcerptTests {
    let labels = DateLabels(now: Fixtures.today, calendar: Fixtures.calendar)

    @Test func relativeDays() {
        #expect(labels.relativeDay(Fixtures.daysAgo(0)) == "Today")
        #expect(labels.relativeDay(Fixtures.daysAgo(1)) == "Yesterday")
        #expect(labels.relativeDay(Fixtures.daysAgo(2)) == "Wed, Oct 7")
        #expect(labels.short(Fixtures.daysAgo(27)) == "Sep 12")
        #expect(labels.time(Fixtures.daysAgo(1, hour: 23, minute: 52)) == "11:52 PM")
        #expect(labels.longDay(Fixtures.today) == "Friday, October 9")
        #expect(labels.fullDate(Fixtures.today) == "October 9, 2026")
        #expect(labels.greeting() == "Good evening")
    }

    @Test func excerptFlattensAndTrimsAtWordBoundary() {
        #expect(Excerpt.make("One\n\nTwo") == "One Two")
        let long = String(repeating: "word ", count: 40)
        let ex = Excerpt.make(long)
        #expect(ex.hasSuffix("…"))
        #expect(ex.count <= 110)
        #expect(!ex.dropLast().hasSuffix(" "))
    }
}
