import Foundation
import XCTest
@testable import EasyJournal

/// 起動時の最初のページ。`-openPage` の有無と、「いま」の月の境目。
/// アプリは起動しない。
final class LaunchPageTests: XCTestCase {
    func testNilOpenPageUsesRouterInitialMonthlyLog() throws {
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
        let router = LaunchPage.makeRouter(openPage: nil, now: now, calendar: calendar)
        let initial = Router(now: now, calendar: calendar)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.current, initial.current)
    }

    func testReadableOpenPageBecomesThatPage() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let october = try makeDate(
            year: 2026,
            month: 10,
            day: 27,
            hour: 12,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let monthly = LaunchPage.makeRouter(openPage: "monthly:2026-12", now: october, calendar: calendar)
        XCTAssertEqual(monthly.current, .monthlyLog(monthKey: "2026-12"))

        let november = try makeDate(
            year: 2026,
            month: 11,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let tracker = LaunchPage.makeRouter(openPage: "tracker:2026-10", now: november, calendar: calendar)
        XCTAssertEqual(tracker.current, .monthlyTracker(monthKey: "2026-10"))

        let january = try makeDate(
            year: 2027,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let daily = LaunchPage.makeRouter(openPage: "daily:2026-10-27", now: january, calendar: calendar)
        XCTAssertEqual(daily.current, .daily(dateKey: "2026-10-27"))
    }

    func testUnreadableOpenPageUsesRouterInitialMonthlyLog() throws {
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
        let invalid = [
            "",
            "daily:2026-02-30",
            "foo:1",
            "Monthly:2026-11",
            "TRACKER:2026-10",
            "DAILY:2026-10-27",
        ]
        for text in invalid {
            let router = LaunchPage.makeRouter(openPage: text, now: now, calendar: calendar)
            XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"), text)
        }
    }

    func testNilOpenPageChangesAtMonthAndYearBoundary() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let endOfOctober = try makeDate(
            year: 2026,
            month: 10,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59,
            calendar: calendar
        )
        let startOfNovember = try makeDate(
            year: 2026,
            month: 11,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let endOfYear = try makeDate(
            year: 2026,
            month: 12,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59,
            calendar: calendar
        )
        let startOfYear = try makeDate(
            year: 2027,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )

        XCTAssertEqual(
            LaunchPage.makeRouter(openPage: nil, now: endOfOctober, calendar: calendar).current,
            .monthlyLog(monthKey: "2026-10")
        )
        XCTAssertEqual(
            LaunchPage.makeRouter(openPage: nil, now: startOfNovember, calendar: calendar).current,
            .monthlyLog(monthKey: "2026-11")
        )
        XCTAssertEqual(
            LaunchPage.makeRouter(openPage: nil, now: endOfYear, calendar: calendar).current,
            .monthlyLog(monthKey: "2026-12")
        )
        XCTAssertEqual(
            LaunchPage.makeRouter(openPage: nil, now: startOfYear, calendar: calendar).current,
            .monthlyLog(monthKey: "2027-01")
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
}
