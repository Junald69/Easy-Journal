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
    ///
    /// 日のページと習慣表も、安全確認が通るまでページを変えない。
    /// 止めたときと失敗したときは、ページを残す。通ったときだけ変える。
    func testGuardedOpenAsksInsteadOfChangingTheMonth() throws {
        let router = try octoberRouter()
        router.beginGuardingMonthlyNavigation()

        router.open(.monthlyLog(monthKey: "2026-11"))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-11")
        XCTAssertNil(router.pageLeaveRequest)

        router.open(.daily(dateKey: "2026-10-27"))
        XCTAssertEqual(
            router.current,
            .monthlyLog(monthKey: "2026-10"),
            "安全確認の前に、日のページへ変わった"
        )
        XCTAssertNil(router.monthRequest)
        let dailyLeave = try XCTUnwrap(router.pageLeaveRequest)
        XCTAssertEqual(dailyLeave.destination, .daily(dateKey: "2026-10-27"))

        XCTAssertFalse(router.resolveGuardedOpen(
            dailyLeave.destination,
            requestToken: dailyLeave.token,
            resolution: .blocked
        ))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertNil(router.pageLeaveRequest)

        router.open(.monthlyTracker(monthKey: "2026-10"))
        let trackerLeave = try XCTUnwrap(router.pageLeaveRequest)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertFalse(router.resolveGuardedOpen(
            trackerLeave.destination,
            requestToken: trackerLeave.token,
            resolution: .failed
        ))
        XCTAssertEqual(
            router.current,
            .monthlyLog(monthKey: "2026-10"),
            "失敗したのにページが変わった"
        )
        XCTAssertNil(router.pageLeaveRequest)

        router.open(.daily(dateKey: "2026-10-27"))
        let passLeave = try XCTUnwrap(router.pageLeaveRequest)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        let wrongDestination = PageLeaveAuthorization.makeForTests(
            destination: .monthlyTracker(monthKey: "2026-10"),
            requestToken: passLeave.token
        )
        XCTAssertFalse(router.resolveGuardedOpen(
            passLeave.destination,
            requestToken: passLeave.token,
            resolution: .passed(wrongDestination)
        ))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertNotNil(router.pageLeaveRequest)

        let passed = PageLeaveAuthorization.makeForTests(
            destination: passLeave.destination,
            requestToken: passLeave.token
        )
        XCTAssertTrue(router.resolveGuardedOpen(
            passLeave.destination,
            requestToken: passLeave.token,
            resolution: .passed(passed)
        ))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
        XCTAssertFalse(router.resolveGuardedOpen(
            passLeave.destination,
            requestToken: passLeave.token,
            resolution: .passed(passed)
        ))
        XCTAssertEqual(
            router.current,
            .daily(dateKey: "2026-10-27"),
            "同じ承諾の再使用でページが変わった"
        )

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
        XCTAssertNil(router.pageLeaveRequest)
        router.open(.monthlyLog(monthKey: "2027-01"))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2027-01"))
        XCTAssertNil(router.monthRequest)
    }

    /// 承諾は移る先の月に結び付き、1回だけ使える。画面が出ていないときは変えない。
    func testMonthMoveAuthorizationIsOneTimeAndBoundToTheMonth() throws {
        let router = try octoberRouter()
        let outside = MonthMoveAuthorization.makeForTests(monthKey: "2026-11", requestToken: nil)
        XCTAssertTrue(outside.isAccepted)
        XCTAssertFalse(router.commitDisplayedMonth("2026-11", authorization: outside))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))

        router.beginGuardingMonthlyNavigation()
        XCTAssertFalse(router.commitDisplayedMonth("2026-13", authorization: outside))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))

        XCTAssertFalse(router.commitDisplayedMonth("2026-12", authorization: outside))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertTrue(router.commitDisplayedMonth("2026-11", authorization: outside))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-11"))

        XCTAssertFalse(router.commitDisplayedMonth("2026-11", authorization: outside))
        XCTAssertFalse(router.commitDisplayedMonth("2026-12", authorization: outside))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-11"))

        XCTAssertFalse(router.commitDisplayedMonth("2026-12", authorization: .rejected))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-11"))

        let tokenBound = MonthMoveAuthorization.makeForTests(monthKey: "2026-12", requestToken: 4)
        XCTAssertFalse(router.commitDisplayedMonth("2026-12", requestToken: nil, authorization: tokenBound))
        XCTAssertFalse(router.commitDisplayedMonth("2026-12", requestToken: 9, authorization: tokenBound))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-11"))
        XCTAssertTrue(router.commitDisplayedMonth("2026-12", requestToken: 4, authorization: tokenBound))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-12"))
        XCTAssertFalse(router.commitDisplayedMonth("2026-12", requestToken: 4, authorization: tokenBound))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-12"))
    }

    /// 月の画面が出ているあいだ、月の URL も依頼になる。日と習慣表の URL も、確認が通るまで開かない。
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

        let tracker = try XCTUnwrap(URL(string: "easyjournal://tracker/2026-10"))
        XCTAssertTrue(router.open(url: tracker, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        let trackerLeave = try XCTUnwrap(router.pageLeaveRequest)
        XCTAssertEqual(trackerLeave.destination, .monthlyTracker(monthKey: "2026-10"))
        XCTAssertFalse(router.resolveGuardedOpen(
            trackerLeave.destination,
            requestToken: trackerLeave.token,
            resolution: .blocked
        ))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))

        let daily = try XCTUnwrap(URL(string: "easyjournal://daily/2026-10-27"))
        XCTAssertTrue(router.open(url: daily, now: now, calendar: calendar))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        let failedLeave = try XCTUnwrap(router.pageLeaveRequest)
        XCTAssertFalse(router.resolveGuardedOpen(
            failedLeave.destination,
            requestToken: failedLeave.token,
            resolution: .failed
        ))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))

        XCTAssertTrue(router.open(url: daily, now: now, calendar: calendar))
        let passLeave = try XCTUnwrap(router.pageLeaveRequest)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        let passed = PageLeaveAuthorization.makeForTests(
            destination: passLeave.destination,
            requestToken: passLeave.token
        )
        XCTAssertTrue(router.resolveGuardedOpen(
            passLeave.destination,
            requestToken: passLeave.token,
            resolution: .passed(passed)
        ))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
        XCTAssertFalse(router.resolveGuardedOpen(
            passLeave.destination,
            requestToken: passLeave.token,
            resolution: .passed(passed)
        ))
        XCTAssertEqual(router.current, .daily(dateKey: "2026-10-27"))
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
