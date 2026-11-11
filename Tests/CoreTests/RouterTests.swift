import Foundation
import XCTest
@testable import EasyJournal

/// 道案内係。最初のページ、open、URL の成功と失敗。
final class RouterTests: XCTestCase {
    func testInitialCurrentIsMonthlyLogForNow() throws {
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

        let october = Router(now: endOfOctober, calendar: calendar)
        XCTAssertEqual(october.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertFalse(october.isIndexPresented)

        let november = Router(now: startOfNovember, calendar: calendar)
        XCTAssertEqual(november.current, .monthlyLog(monthKey: "2026-11"))

        let december = Router(now: endOfYear, calendar: calendar)
        XCTAssertEqual(december.current, .monthlyLog(monthKey: "2026-12"))

        let january = Router(now: startOfYear, calendar: calendar)
        XCTAssertEqual(january.current, .monthlyLog(monthKey: "2027-01"))
    }

    func testOpenChangesCurrentOnly() throws {
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
        let router = Router(now: now, calendar: calendar)
        router.isIndexPresented = true

        router.open(.daily(dateKey: "2026-10-27"))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
        XCTAssertTrue(router.isIndexPresented)

        router.open(.monthlyTracker(monthKey: "2026-11"))
        XCTAssertEqual(router.current, .monthlyTracker(monthKey: "2026-11"))
        XCTAssertTrue(router.isIndexPresented)

        router.open(.monthlyLog(monthKey: "2027-01"))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2027-01"))
        XCTAssertTrue(router.isIndexPresented)
    }

    func testOpenURLReturnsTrueAndMoves() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let october = try makeDate(
            year: 2026,
            month: 10,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59,
            calendar: calendar
        )
        let january = try makeDate(
            year: 2027,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            calendar: calendar
        )
        let router = Router(now: october, calendar: calendar)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))

        let dailyURL = try XCTUnwrap(URL(string: "easyjournal://daily/2026-10-27"))
        XCTAssertTrue(router.open(url: dailyURL, now: october, calendar: calendar))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))

        let todayURL = try XCTUnwrap(URL(string: "easyjournal://monthly/today"))
        XCTAssertTrue(router.open(url: todayURL, now: january, calendar: calendar))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2027-01"))

        let trackerURL = try XCTUnwrap(URL(string: "easyjournal://tracker/2026-10"))
        XCTAssertTrue(router.open(url: trackerURL, now: january, calendar: calendar))
        XCTAssertEqual(router.current, .monthlyTracker(monthKey: "2026-10"))
    }

    func testOpenURLReturnsFalseAndKeepsCurrent() throws {
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
        let router = Router(now: now, calendar: calendar)
        router.open(.daily(dateKey: "2026-10-27"))
        router.isIndexPresented = true

        let wrongScheme = try XCTUnwrap(URL(string: "https://example.com/daily/today"))
        XCTAssertFalse(router.open(url: wrongScheme, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
        XCTAssertTrue(router.isIndexPresented)

        let missingDay = try XCTUnwrap(URL(string: "easyjournal://daily/2026-02-30"))
        XCTAssertFalse(router.open(url: missingDay, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))

        let trackerToday = try XCTUnwrap(URL(string: "easyjournal://tracker/today"))
        XCTAssertFalse(router.open(url: trackerToday, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))

        let noPath = try XCTUnwrap(URL(string: "easyjournal://daily"))
        XCTAssertFalse(router.open(url: noPath, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
    }

    /// 依頼だけでは、表示している月は変わらない。承諾したときだけ変わる。
    func testRequestMonthWaitsForCommit() throws {
        let router = try octoberRouter()
        XCTAssertNil(router.monthRequest)

        router.requestMonth("2026-11")
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-11")
        let firstToken = try XCTUnwrap(router.monthRequest).token

        router.requestMonth("2026-13")
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-11")
        XCTAssertEqual(router.monthRequest?.token, firstToken)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))

        router.requestMonth("2027-01")
        XCTAssertEqual(router.monthRequest?.monthKey, "2027-01")
        XCTAssertNotEqual(router.monthRequest?.token, firstToken)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))

        router.commitDisplayedMonth("2026-13", authorization: .rejected)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2027-01")

        router.commitDisplayedMonth("2027-01", authorization: .rejected)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2027-01")
    }

    /// 画面の外の承諾では、ガードの前後どちらでも月は変わらない。
    /// 画面が出る前の依頼は、表示月を変えずに残る。画面が現れてから片付ける。
    func testOutsideCommitDoesNotChangeTheMonth() throws {
        let router = try octoberRouter()
        router.requestMonth("2026-12")
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-12")

        router.commitDisplayedMonth("2026-11", authorization: .rejected)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-12")

        router.beginGuardingMonthlyNavigation()
        router.commitDisplayedMonth("2026-11", authorization: .rejected)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-12")
        XCTAssertFalse(MonthMoveAuthorization.rejected.isAccepted)
    }

    /// 月の画面が出ているあいだ、別の月への open は依頼になる。表示月は変えない。
    func testGuardedOpenAsksInsteadOfChangingTheMonth() throws {
        let router = try octoberRouter()
        router.beginGuardingMonthlyNavigation()

        router.open(.monthlyLog(monthKey: "2026-11"))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-11")

        router.open(.daily(dateKey: "2026-10-27"))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
        XCTAssertNil(router.monthRequest)

        router.open(.monthlyLog(monthKey: "2026-10"))
        router.beginGuardingMonthlyNavigation()
        router.commitDisplayedMonth("2026-12", authorization: .rejected)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertNil(router.monthRequest)

        router.open(.monthlyLog(monthKey: "2026-11"))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-11")

        router.endGuardingMonthlyNavigation()
        XCTAssertNil(router.monthRequest)
        router.open(.monthlyLog(monthKey: "2027-01"))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2027-01"))
        XCTAssertNil(router.monthRequest)
    }

    /// 月の画面が出ているあいだ、月の URL も依頼になる。日の URL は、今までどおり開く。
    func testGuardedURLOpenAsksForAnotherMonth() throws {
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
        let router = Router(now: now, calendar: calendar)
        router.beginGuardingMonthlyNavigation()

        let monthly = try XCTUnwrap(URL(string: "easyjournal://monthly/2026-12"))
        XCTAssertTrue(router.open(url: monthly, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-12")

        let today = try XCTUnwrap(URL(string: "easyjournal://monthly/today"))
        XCTAssertTrue(router.open(url: today, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertNil(router.monthRequest)

        let daily = try XCTUnwrap(URL(string: "easyjournal://daily/2026-10-27"))
        XCTAssertTrue(router.open(url: daily, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
        XCTAssertNil(router.monthRequest)
    }

    private func octoberRouter() throws -> Router {
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
        return Router(now: now, calendar: calendar)
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
