import Testing
import Foundation
@testable import MementoCore

@Suite struct StreakTests {
    @Test func countsBackFromYesterdayWhenNothingToday() {
        let dates = [1, 2, 3, 5].map { Fixtures.daysAgo($0) }
        let info = Streak.compute(entryDates: dates, today: Fixtures.today, calendar: Fixtures.calendar)
        #expect(info.count == 3)
        #expect(info.unit == "days in a row")
    }

    @Test func includesTodayAndBuildsMondayWeek() {
        let dates = [0, 1].map { Fixtures.daysAgo($0) }
        let info = Streak.compute(entryDates: dates, today: Fixtures.today, calendar: Fixtures.calendar)
        #expect(info.count == 2)
        #expect(info.week.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(info.week[4].isToday)          // Friday
        #expect(info.week[3].hasEntry && info.week[4].hasEntry)
        #expect(!info.week[0].hasEntry)
    }

    @Test func singleDayUnit() {
        let info = Streak.compute(entryDates: [Fixtures.daysAgo(0)], today: Fixtures.today, calendar: Fixtures.calendar)
        #expect(info.count == 1)
        #expect(info.unit == "day in a row")
        #expect(Streak.compute(entryDates: [], today: Fixtures.today, calendar: Fixtures.calendar).count == 0)
    }
}
