import Foundation
import XCTest
@testable import EasyJournal

/// 日付キーのルール。タイムゾーンはテストごとに明示する。端末の設定には頼らない。
final class DateKeyTests: XCTestCase {
    // MARK: - A. キーの計算（タイムゾーンに依存しない）

    func testNextDayKeyCrossesMonthEnd() {
        XCTAssertEqual(DateKey.nextDayKey(after: "2026-01-31"), "2026-02-01")
        XCTAssertEqual(DateKey.nextDayKey(after: "2026-04-30"), "2026-05-01")
    }

    func testDayKeyCrossesYearBoundary() {
        XCTAssertEqual(DateKey.nextDayKey(after: "2026-12-31"), "2027-01-01")
        XCTAssertEqual(DateKey.previousDayKey(before: "2027-01-01"), "2026-12-31")
    }

    /// 2026年10月→11月→10月。12月の次は翌年1月。1月の前は前年12月。
    func testMonthKeyStepsAcrossMonthsAndYears() {
        XCTAssertEqual(DateKey.nextMonthKey(after: "2026-10"), "2026-11")
        XCTAssertEqual(DateKey.previousMonthKey(before: "2026-11"), "2026-10")
        XCTAssertEqual(DateKey.nextMonthKey(after: "2026-12"), "2027-01")
        XCTAssertEqual(DateKey.previousMonthKey(before: "2027-01"), "2026-12")
        XCTAssertEqual(DateKey.previousMonthKey(before: "2026-01"), "2025-12")
        XCTAssertEqual(DateKey.nextMonthKey(after: "2028-02"), "2028-03")
    }

    func testLeapYearDayKeys() {
        XCTAssertEqual(DateKey.nextDayKey(after: "2028-02-28"), "2028-02-29")
        XCTAssertEqual(DateKey.nextDayKey(after: "2028-02-29"), "2028-03-01")
        XCTAssertEqual(DateKey.nextDayKey(after: "2026-02-28"), "2026-03-01")
        XCTAssertTrue(DateKey.isValidDayKey("2000-02-29"))
        XCTAssertFalse(DateKey.isValidDayKey("2026-02-29"))
    }

    func testCenturyNonLeapYear() {
        XCTAssertEqual(DateKey.nextDayKey(after: "2100-02-28"), "2100-03-01")
        XCTAssertFalse(DateKey.isValidDayKey("2100-02-29"))
    }

    func testDaysInEachMonth() {
        let months = [
            "2026-01", "2026-02", "2026-03", "2026-04",
            "2026-05", "2026-06", "2026-07", "2026-08",
            "2026-09", "2026-10", "2026-11", "2026-12",
        ]
        let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        for (monthKey, expected) in zip(months, days) {
            XCTAssertEqual(DateKey.daysInMonth(monthKey: monthKey), Optional(expected), monthKey)
        }
        XCTAssertEqual(DateKey.daysInMonth(monthKey: "2028-02"), 29)
        XCTAssertEqual(DateKey.daysInMonth(monthKey: "2100-02"), 28)
        XCTAssertNil(DateKey.daysInMonth(monthKey: "2026-13"))
    }

    func testDayKeysInMonth() {
        let february2026 = DateKey.dayKeys(inMonth: "2026-02")
        XCTAssertEqual(february2026.count, 28)
        XCTAssertEqual(february2026.first, "2026-02-01")
        XCTAssertEqual(february2026.last, "2026-02-28")

        let february2028 = DateKey.dayKeys(inMonth: "2028-02")
        XCTAssertEqual(february2028.count, 29)
        XCTAssertEqual(february2028.first, "2028-02-01")
        XCTAssertEqual(february2028.last, "2028-02-29")

        XCTAssertEqual(DateKey.dayKeys(inMonth: "2026-13"), [])
    }

    func testWeekdayOfKnownDayKeys() {
        XCTAssertEqual(DateKey.weekday(ofDayKey: "2026-10-28"), Optional(DateKey.Weekday.wednesday))
        XCTAssertEqual(DateKey.weekday(ofDayKey: "2026-01-01"), Optional(DateKey.Weekday.thursday))
        XCTAssertEqual(DateKey.weekday(ofDayKey: "2028-02-29"), Optional(DateKey.Weekday.tuesday))
        XCTAssertNil(DateKey.weekday(ofDayKey: "2026-02-30"))
    }

    func testRejectsInvalidKeyFormats() {
        let invalidDayKeys = [
            "2026-1-5",
            "2026-10-27 ",
            "",
            "abc",
            "2026-02-30",
            "2026-13-01",
            "2026-00-10",
            "2026-10-00",
            "2026-10",
        ]
        for dayKey in invalidDayKeys {
            XCTAssertFalse(DateKey.isValidDayKey(dayKey), dayKey)
            XCTAssertNil(DateKey.nextDayKey(after: dayKey), dayKey)
            XCTAssertNil(DateKey.previousDayKey(before: dayKey), dayKey)
        }

        XCTAssertFalse(DateKey.isValidMonthKey("2026-10-27"))
        XCTAssertFalse(DateKey.isValidMonthKey("2026-1"))
        XCTAssertFalse(DateKey.isValidMonthKey("2026-13"))
        XCTAssertFalse(DateKey.isValidMonthKey(""))
        XCTAssertNil(DateKey.nextMonthKey(after: "2026-13"))
        XCTAssertNil(DateKey.previousMonthKey(before: "2026-13"))
        XCTAssertNil(DateKey.nextMonthKey(after: ""))
        XCTAssertNil(DateKey.previousMonthKey(before: "2026-1"))
        XCTAssertTrue(DateKey.isValidDayKey("2026-10-27"))
        XCTAssertTrue(DateKey.isValidMonthKey("2026-10"))
        XCTAssertEqual(DateKey.monthKey(ofDayKey: "2026-10-27"), "2026-10")
        XCTAssertNil(DateKey.monthKey(ofDayKey: "2026-10"))
        XCTAssertNil(DateKey.monthKey(ofDayKey: "2026-02-30"))
    }

    // MARK: - B. 瞬間とキー（タイムゾーンあり）

    func testTokyoMidnightBoundary() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let beforeMidnight = try makeDate(
            year: 2026,
            month: 10,
            day: 27,
            hour: 23,
            minute: 59,
            second: 59,
            calendar: calendar
        )
        let midnight = try makeDate(
            year: 2026,
            month: 10,
            day: 28,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        XCTAssertEqual(DateKey.dayKey(from: beforeMidnight, calendar: calendar), "2026-10-27")
        XCTAssertEqual(DateKey.monthKey(from: beforeMidnight, calendar: calendar), "2026-10")
        XCTAssertEqual(DateKey.dayKey(from: midnight, calendar: calendar), "2026-10-28")
    }

    func testNewYorkDaylightSavingDayLength() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "America/New_York")
        let march7 = try XCTUnwrap(DateKey.startOfDay(for: "2026-03-07", calendar: calendar))
        let march8 = try XCTUnwrap(DateKey.startOfDay(for: "2026-03-08", calendar: calendar))
        let march9 = try XCTUnwrap(DateKey.startOfDay(for: "2026-03-09", calendar: calendar))
        XCTAssertLessThan(march7, march8)
        XCTAssertLessThan(march8, march9)
        XCTAssertEqual(march9.timeIntervalSince(march8), 82800, accuracy: 1)

        let november1 = try XCTUnwrap(DateKey.startOfDay(for: "2026-11-01", calendar: calendar))
        let november2 = try XCTUnwrap(DateKey.startOfDay(for: "2026-11-02", calendar: calendar))
        XCTAssertLessThan(november1, november2)
        XCTAssertEqual(november2.timeIntervalSince(november1), 90000, accuracy: 1)
    }

    func testNewYorkTransitionClockTimes() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "America/New_York")
        let springLate = try makeDate(
            year: 2026,
            month: 3,
            day: 8,
            hour: 23,
            minute: 30,
            second: 0,
            calendar: calendar
        )
        let fallEarly = try makeDate(
            year: 2026,
            month: 11,
            day: 1,
            hour: 0,
            minute: 30,
            second: 0,
            calendar: calendar
        )
        let fallLate = try makeDate(
            year: 2026,
            month: 11,
            day: 1,
            hour: 23,
            minute: 30,
            second: 0,
            calendar: calendar
        )
        XCTAssertEqual(DateKey.dayKey(from: springLate, calendar: calendar), "2026-03-08")
        XCTAssertEqual(DateKey.dayKey(from: fallEarly, calendar: calendar), "2026-11-01")
        XCTAssertEqual(DateKey.dayKey(from: fallLate, calendar: calendar), "2026-11-01")
    }

    func testRoundTripAcrossNewYorkSpringForward() throws {
        try assertRoundTrip(
            dayKeys: ["2026-03-07", "2026-03-08", "2026-03-09", "2026-03-10"],
            timeZoneIdentifier: "America/New_York"
        )
    }

    func testRoundTripAcrossNewYorkFallBack() throws {
        try assertRoundTrip(
            dayKeys: ["2026-10-31", "2026-11-01", "2026-11-02", "2026-11-03"],
            timeZoneIdentifier: "America/New_York"
        )
    }

    func testSameInstantHasDifferentDayKeysByTimeZone() throws {
        let instant = try makeUTCDate(year: 2026, month: 10, day: 27, hour: 15, minute: 30, second: 0)
        let expectations = [
            ("Asia/Tokyo", "2026-10-28"),
            ("Pacific/Honolulu", "2026-10-27"),
            ("Pacific/Kiritimati", "2026-10-28"),
            ("Pacific/Pago_Pago", "2026-10-27"),
        ]
        for (identifier, expected) in expectations {
            let calendar = try makeCalendar(timeZoneIdentifier: identifier)
            XCTAssertEqual(DateKey.dayKey(from: instant, calendar: calendar), expected, identifier)
        }
        let kiritimati = try makeCalendar(timeZoneIdentifier: "Pacific/Kiritimati")
        let pagoPago = try makeCalendar(timeZoneIdentifier: "Pacific/Pago_Pago")
        XCTAssertNotEqual(
            DateKey.dayKey(from: instant, calendar: kiritimati),
            DateKey.dayKey(from: instant, calendar: pagoPago)
        )
    }

    func testApiaDayAfterMissingDateDoesNotCrash() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Pacific/Apia")
        let instant = try makeDate(
            year: 2011,
            month: 12,
            day: 31,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        XCTAssertEqual(DateKey.dayKey(from: instant, calendar: calendar), "2011-12-31")
        // 2011-12-30 は Apia に存在しない日。返り値は未確認なので、落ちないことだけ見る。
        _ = DateKey.startOfDay(for: "2011-12-30", calendar: calendar)
    }

    func testMakeCalendarStaysGregorian() throws {
        let buddhist = Calendar(identifier: .buddhist)
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let calendar = DateKey.makeCalendar(timeZone: timeZone)
        XCTAssertEqual(buddhist.identifier, .buddhist)
        XCTAssertEqual(calendar.identifier, .gregorian)

        let instant = try makeDate(
            year: 2026,
            month: 10,
            day: 27,
            hour: 12,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        XCTAssertEqual(DateKey.dayKey(from: instant, calendar: calendar), "2026-10-27")
    }

    func testDayKeyIgnoresNonGregorianCalendarIdentifier() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = timeZone
        let gregorian = DateKey.makeCalendar(timeZone: timeZone)
        let instant = try makeDate(
            year: 2026,
            month: 10,
            day: 28,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: gregorian
        )
        XCTAssertEqual(DateKey.dayKey(from: instant, calendar: buddhist), "2026-10-28")
        XCTAssertEqual(DateKey.monthKey(from: instant, calendar: buddhist), "2026-10")
    }

    func testStartOfDayIgnoresNonGregorianCalendarIdentifier() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = timeZone
        let start = try XCTUnwrap(DateKey.startOfDay(for: "2026-10-28", calendar: buddhist))
        let gregorian = DateKey.makeCalendar(timeZone: timeZone)
        XCTAssertEqual(DateKey.dayKey(from: start, calendar: gregorian), "2026-10-28")
    }

    func testStartOfDayRoundTripsToMidnightInTokyo() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let start = try XCTUnwrap(DateKey.startOfDay(for: "2026-10-28", calendar: calendar))
        XCTAssertEqual(DateKey.dayKey(from: start, calendar: calendar), "2026-10-28")
        let parts = calendar.dateComponents([.hour, .minute, .second], from: start)
        XCTAssertEqual(parts.hour, Optional(0))
        XCTAssertEqual(parts.minute, Optional(0))
        XCTAssertEqual(parts.second, Optional(0))
    }

    func testStartOfDayReturnsNilForInvalidKey() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        XCTAssertNil(DateKey.startOfDay(for: "2026-02-30", calendar: calendar))
        XCTAssertNil(DateKey.startOfDay(for: "2026-1-5", calendar: calendar))
        XCTAssertNil(DateKey.startOfDay(for: "2026-10-27 ", calendar: calendar))
        XCTAssertNil(DateKey.startOfDay(for: "", calendar: calendar))
        XCTAssertNil(DateKey.startOfDay(for: "abc", calendar: calendar))
    }

    // MARK: - C. アプリを開いたまま日付が変わる（時計は引数）

    func testTodayKeyRecalculatesAcrossMidnight() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let beforeMidnight = try makeDate(
            year: 2026,
            month: 10,
            day: 27,
            hour: 23,
            minute: 59,
            second: 30,
            calendar: calendar
        )
        let afterMidnight = try makeDate(
            year: 2026,
            month: 10,
            day: 28,
            hour: 0,
            minute: 0,
            second: 30,
            calendar: calendar
        )
        XCTAssertEqual(DateKey.todayKey(now: beforeMidnight, calendar: calendar), "2026-10-27")
        XCTAssertEqual(DateKey.todayKey(now: afterMidnight, calendar: calendar), "2026-10-28")
    }

    func testTodayKeyChangesWhenCalendarTimeZoneChanges() throws {
        let instant = try makeUTCDate(year: 2026, month: 10, day: 27, hour: 15, minute: 30, second: 0)
        let tokyo = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let honolulu = try makeCalendar(timeZoneIdentifier: "Pacific/Honolulu")
        XCTAssertEqual(DateKey.todayKey(now: instant, calendar: tokyo), "2026-10-28")
        XCTAssertEqual(DateKey.todayKey(now: instant, calendar: honolulu), "2026-10-27")
    }

    func testTodayKeyOnRepeatedNewYorkOneThirty() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "America/New_York")
        let first = try makeUTCDate(year: 2026, month: 11, day: 1, hour: 5, minute: 30, second: 0)
        let second = try makeUTCDate(year: 2026, month: 11, day: 1, hour: 6, minute: 30, second: 0)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(DateKey.todayKey(now: first, calendar: calendar), "2026-11-01")
        XCTAssertEqual(DateKey.todayKey(now: second, calendar: calendar), "2026-11-01")
    }

    // MARK: - テスト用の瞬間

    private func makeCalendar(timeZoneIdentifier: String) throws -> Calendar {
        let timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
        return DateKey.makeCalendar(timeZone: timeZone)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        calendar: Calendar
    ) throws -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return try makeDate(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second,
            calendar: calendar
        )
    }

    private func assertRoundTrip(dayKeys: [String], timeZoneIdentifier: String) throws {
        let calendar = try makeCalendar(timeZoneIdentifier: timeZoneIdentifier)
        var previous: Date?
        for dayKey in dayKeys {
            let start = try XCTUnwrap(DateKey.startOfDay(for: dayKey, calendar: calendar))
            XCTAssertEqual(DateKey.dayKey(from: start, calendar: calendar), dayKey)
            if let previous {
                XCTAssertLessThan(previous, start)
            }
            previous = start
        }
    }
}
