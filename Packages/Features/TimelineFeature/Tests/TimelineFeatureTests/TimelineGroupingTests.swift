import Testing
import Foundation
import Persistence

struct TimelineGroupingTests {

    // MARK: - testLabelsForTodayYesterday

    @Test
    func testLabelsForTodayYesterday() {
        // Create a fixed calendar for deterministic testing
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Reference date: Thursday January 15, 2026 at noon
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

        // Today: same day, different time
        let todayMorning = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 8))!
        let todayEvening = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 20))!

        #expect(DateBucket.bucket(for: todayMorning, relativeTo: reference, calendar: calendar) == .today)
        #expect(DateBucket.bucket(for: todayEvening, relativeTo: reference, calendar: calendar) == .today)
        #expect(DateBucket.bucket(for: reference, relativeTo: reference, calendar: calendar) == .today)

        // Yesterday: the day before reference
        let yesterdayMorning = calendar.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 8))!
        let yesterdayNight = calendar.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 23, minute: 59))!

        #expect(DateBucket.bucket(for: yesterdayMorning, relativeTo: reference, calendar: calendar) == .yesterday)
        #expect(DateBucket.bucket(for: yesterdayNight, relativeTo: reference, calendar: calendar) == .yesterday)
    }

    // MARK: - testThisWeekNotTodayOrYesterday

    @Test
    func testThisWeekNotTodayOrYesterday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday

        // Reference: Thursday January 15, 2026 (week 3: Jan 11-17)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

        // Earlier in the same week (not today or yesterday)
        // Week containing Jan 15 starts on Sunday Jan 11
        let sundayThisWeek = calendar.date(from: DateComponents(year: 2026, month: 1, day: 11, hour: 10))!
        let mondayThisWeek = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 10))!
        let tuesdayThisWeek = calendar.date(from: DateComponents(year: 2026, month: 1, day: 13, hour: 10))!

        #expect(DateBucket.bucket(for: sundayThisWeek, relativeTo: reference, calendar: calendar) == .thisWeek)
        #expect(DateBucket.bucket(for: mondayThisWeek, relativeTo: reference, calendar: calendar) == .thisWeek)
        #expect(DateBucket.bucket(for: tuesdayThisWeek, relativeTo: reference, calendar: calendar) == .thisWeek)
    }

    // MARK: - testLastWeek

    @Test
    func testLastWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday

        // Reference: Thursday January 15, 2026 (week 3: Jan 11-17)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

        // Last week (week 2): Sunday Jan 4 to Saturday Jan 10
        let lastWeekStart = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4, hour: 10))!
        let lastWeekEnd = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 23))!

        #expect(DateBucket.bucket(for: lastWeekStart, relativeTo: reference, calendar: calendar) == .lastWeek)
        #expect(DateBucket.bucket(for: lastWeekEnd, relativeTo: reference, calendar: calendar) == .lastWeek)
    }

    // MARK: - testThisMonthNotInWeeks

    @Test
    func testThisMonthNotInWeeks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday

        // Reference: Thursday January 15, 2026
        // Week 3: Jan 11-17 (this week)
        // Week 2: Jan 4-10 (last week)
        // Week 1: Dec 28-Jan 3 (this month portion)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

        // Start of month before last week (Jan 1-3 are in week 1)
        let jan1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 10))!
        let jan3 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 10))!

        #expect(DateBucket.bucket(for: jan1, relativeTo: reference, calendar: calendar) == .thisMonth)
        #expect(DateBucket.bucket(for: jan3, relativeTo: reference, calendar: calendar) == .thisMonth)
    }

    // MARK: - testOlder

    @Test
    func testOlder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Reference: Thursday January 15, 2026
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

        // Previous month
        let december = calendar.date(from: DateComponents(year: 2025, month: 12, day: 25, hour: 10))!
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 10))!

        #expect(DateBucket.bucket(for: december, relativeTo: reference, calendar: calendar) == .older)
        #expect(DateBucket.bucket(for: lastYear, relativeTo: reference, calendar: calendar) == .older)
    }

    // MARK: - testBucketOrderingAllCases

    @Test
    func testBucketOrderingAllCases() {
        // Verify the allCases are in the expected display order
        let expected: [DateBucket] = [.today, .yesterday, .thisWeek, .lastWeek, .thisMonth, .older]
        #expect(DateBucket.allCases == expected)
    }

    // MARK: - testEdgeCaseMidnight

    @Test
    func testEdgeCaseMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Reference: January 15, 2026 at midnight
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 0, minute: 0, second: 0))!

        // Just before midnight on the 14th (should be yesterday)
        let beforeMidnight = calendar.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 23, minute: 59, second: 59))!

        // Just after midnight on the 15th (should be today)
        let afterMidnight = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 0, minute: 0, second: 1))!

        #expect(DateBucket.bucket(for: beforeMidnight, relativeTo: reference, calendar: calendar) == .yesterday)
        #expect(DateBucket.bucket(for: afterMidnight, relativeTo: reference, calendar: calendar) == .today)
    }
}
