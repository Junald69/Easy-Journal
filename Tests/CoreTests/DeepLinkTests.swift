import Foundation
import XCTest
@testable import EasyJournal

/// `easyjournal://` をページ指定に変える。`today` は渡した「いま」と暦で決まる。
final class DeepLinkTests: XCTestCase {
    func testFiveLinksBecomePageRefs() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let now = try makeDate(
            year: 2026,
            month: 10,
            day: 27,
            hour: 12,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let samples: [(String, PageRef)] = [
            ("easyjournal://daily/today", .daily(dateKey: "2026-10-27")),
            ("easyjournal://daily/2026-10-27", .daily(dateKey: "2026-10-27")),
            ("easyjournal://monthly/2026-10", .monthlyLog(monthKey: "2026-10")),
            ("easyjournal://monthly/today", .monthlyLog(monthKey: "2026-10")),
            ("easyjournal://tracker/2026-10", .monthlyTracker(monthKey: "2026-10")),
        ]
        for (text, expected) in samples {
            assertLink(text, equals: expected, now: now, calendar: calendar)
        }

        let otherNow = try makeDate(
            year: 2027,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        assertLink(
            "easyjournal://daily/2026-10-27",
            equals: .daily(dateKey: "2026-10-27"),
            now: otherNow,
            calendar: calendar
        )
        assertLink(
            "easyjournal://tracker/2026-10",
            equals: .monthlyTracker(monthKey: "2026-10"),
            now: otherNow,
            calendar: calendar
        )
        assertLink(
            "easyjournal://monthly/2026-10",
            equals: .monthlyLog(monthKey: "2026-10"),
            now: otherNow,
            calendar: calendar
        )
    }

    func testTodayChangesAcrossMonthBoundary() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let beforeMidnight = try makeDate(
            year: 2026,
            month: 10,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59,
            calendar: calendar
        )
        let midnight = try makeDate(
            year: 2026,
            month: 11,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        assertLink(
            "easyjournal://daily/today",
            equals: .daily(dateKey: "2026-10-31"),
            now: beforeMidnight,
            calendar: calendar
        )
        assertLink(
            "easyjournal://daily/today",
            equals: .daily(dateKey: "2026-11-01"),
            now: midnight,
            calendar: calendar
        )
        assertLink(
            "easyjournal://monthly/today",
            equals: .monthlyLog(monthKey: "2026-10"),
            now: beforeMidnight,
            calendar: calendar
        )
        assertLink(
            "easyjournal://monthly/today",
            equals: .monthlyLog(monthKey: "2026-11"),
            now: midnight,
            calendar: calendar
        )
    }

    func testTodayChangesAcrossYearBoundary() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let beforeMidnight = try makeDate(
            year: 2026,
            month: 12,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59,
            calendar: calendar
        )
        let midnight = try makeDate(
            year: 2027,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        assertLink(
            "easyjournal://daily/today",
            equals: .daily(dateKey: "2026-12-31"),
            now: beforeMidnight,
            calendar: calendar
        )
        assertLink(
            "easyjournal://daily/today",
            equals: .daily(dateKey: "2027-01-01"),
            now: midnight,
            calendar: calendar
        )
        assertLink(
            "easyjournal://monthly/today",
            equals: .monthlyLog(monthKey: "2026-12"),
            now: beforeMidnight,
            calendar: calendar
        )
        assertLink(
            "easyjournal://monthly/today",
            equals: .monthlyLog(monthKey: "2027-01"),
            now: midnight,
            calendar: calendar
        )
    }

    /// 同じ瞬間でも、暦のタイムゾーンが違えば「今日」の日が変わる。
    /// 2026-10-31 15:00 UTC は、東京では 2026-11-01 00:00、ニューヨークでは 2026-10-31 の昼。
    func testTodayFollowsCalendarTimeZone() throws {
        let instant = try makeUTCDate(year: 2026, month: 10, day: 31, hour: 15, minute: 0, second: 0)
        let tokyo = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let newYork = try makeCalendar(timeZoneIdentifier: "America/New_York")
        assertLink(
            "easyjournal://daily/today",
            equals: .daily(dateKey: "2026-11-01"),
            now: instant,
            calendar: tokyo
        )
        assertLink(
            "easyjournal://daily/today",
            equals: .daily(dateKey: "2026-10-31"),
            now: instant,
            calendar: newYork
        )
        assertLink(
            "easyjournal://monthly/today",
            equals: .monthlyLog(monthKey: "2026-11"),
            now: instant,
            calendar: tokyo
        )
        assertLink(
            "easyjournal://monthly/today",
            equals: .monthlyLog(monthKey: "2026-10"),
            now: instant,
            calendar: newYork
        )
    }

    func testInvalidLinksReturnNil() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let now = try makeDate(
            year: 2026,
            month: 10,
            day: 27,
            hour: 12,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        // URL 型がスラッシュの繰り返しやユーザー情報を書き換えても、結果がぶれないもの。
        let invalidForTextAndURL = [
            "",
            "easyjournal://daily",
            "easyjournal://daily/2026-10-27/extra",
            "easyjournal://daily/2026-02-30",
            "easyjournal://daily/2026-13-01",
            "easyjournal://daily/2026-02-29",
            "easyjournal://daily/2026-10",
            "easyjournal://monthly/2026-13",
            "easyjournal://monthly/2026-10-27",
            "easyjournal://tracker/today",
            "easyjournal://tracker/2026-13",
            "easyjournal://tracker/2026-10/extra",
            "easyjournal://weekly/2026-10",
            "https://daily/today",
            "http://easyjournal/daily/today",
            "easyjournal://daily/today?x=1",
            "easyjournal://daily/today#top",
            "easyjournal://daily/2026-1-05",
            "easyjournal://monthly/2026-1",
            "easyjournal://monthly/today/extra",
            "easyjournal://tracker/2026-10-01",
        ]
        for text in invalidForTextAndURL {
            XCTAssertNil(DeepLink.pageRef(from: text, now: now, calendar: calendar), text)
            if let url = URL(string: text) {
                XCTAssertNil(
                    DeepLink.pageRef(from: url, now: now, calendar: calendar),
                    "\(text) absoluteString=\(url.absoluteString)"
                )
            }
        }

        // 大文字、空白、URL 型が形を変えるかもしれないもの。文字列の入口だけを見る。
        let invalidTextOnly = [
            " easyjournal://daily/today",
            "easyjournal://daily/today ",
            "easyjournal://daily/Today",
            "easyjournal://Daily/today",
            "EASYJOURNAL://daily/today",
            "easyjournal://MONTHLY/2026-10",
            "easyjournal://daily/TODAY",
            "easyjournal://monthly/Today",
            "\teasyjournal://daily/today",
            "easyjournal://daily/today\n",
            "easyjournal://daily/",
            "easyjournal://daily/today/",
            "easyjournal:///today",
            "easyjournal://daily//2026-10-27",
            "easyjournal:daily/today",
            "easyjournal://daily:80/today",
            "easyjournal://user@daily/today",
        ]
        for text in invalidTextOnly {
            XCTAssertNil(DeepLink.pageRef(from: text, now: now, calendar: calendar), text)
        }
    }

    private func assertLink(
        _ text: String,
        equals expected: PageRef,
        now: Date,
        calendar: Calendar,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            DeepLink.pageRef(from: text, now: now, calendar: calendar),
            Optional(expected),
            text,
            file: file,
            line: line
        )
        guard let url = URL(string: text) else {
            XCTFail("URL にできない: \(text)", file: file, line: line)
            return
        }
        XCTAssertEqual(
            DeepLink.pageRef(from: url, now: now, calendar: calendar),
            Optional(expected),
            "absoluteString=\(url.absoluteString)",
            file: file,
            line: line
        )
    }

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
}
