import Foundation
import XCTest
@testable import EasyJournal

/// 起動引数 `-todayKey` を読めるか。アプリは起動しない。
final class TodayKeyLaunchOptionsTests: XCTestCase {
    func testReadsTodayKeyArgument() {
        let options = LaunchOptions(arguments: [
            "EasyJournal",
            "-sampleData",
            "-inMemoryStore",
            "-openPage",
            "monthly:2026-10",
            "-todayKey",
            "2026-10-27",
        ])
        XCTAssertEqual(options.todayKey, "2026-10-27")
        XCTAssertTrue(options.sampleData)
        XCTAssertTrue(options.inMemoryStore)
        XCTAssertEqual(options.openPage, "monthly:2026-10")

        let missing = LaunchOptions(arguments: ["EasyJournal", "-todayKey"])
        XCTAssertNil(missing.todayKey)

        let absent = LaunchOptions(arguments: ["EasyJournal", "-sampleData"])
        XCTAssertNil(absent.todayKey)
    }

    /// Debug かつメモリ上の保存先で、正しい日付キーのときだけ固定する。
    /// now が変わっても固定値のまま。Release や、メモリ上でないときは使わない。
    func testResolvedTodayKeyHonorsInMemoryAndValidDay() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "UTC")
        let noon = try makeDate(
            year: 2026, month: 10, day: 28, hour: 12, minute: 0, second: 0, calendar: calendar
        )
        let evening = try makeDate(
            year: 2026, month: 10, day: 28, hour: 23, minute: 0, second: 0, calendar: calendar
        )
        XCTAssertEqual(DateKey.todayKey(now: noon, calendar: calendar), "2026-10-28")

        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: "2026-10-27",
                inMemoryStore: true,
                isDebugBuild: true,
                now: noon,
                calendar: calendar
            ),
            "2026-10-27"
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: "2026-10-27",
                inMemoryStore: true,
                isDebugBuild: true,
                now: evening,
                calendar: calendar
            ),
            "2026-10-27"
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: "2026-10-32",
                inMemoryStore: true,
                isDebugBuild: true,
                now: noon,
                calendar: calendar
            ),
            "2026-10-28"
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: "2026-10-27",
                inMemoryStore: false,
                isDebugBuild: true,
                now: noon,
                calendar: calendar
            ),
            "2026-10-28"
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: "2026-10-27",
                inMemoryStore: true,
                isDebugBuild: false,
                now: noon,
                calendar: calendar
            ),
            "2026-10-28"
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: "2026-10-27",
                inMemoryStore: false,
                isDebugBuild: false,
                now: noon,
                calendar: calendar
            ),
            "2026-10-28"
        )
    }

    /// 固定が無く、Debug でもメモリ上でもないときは、now から計算する。
    func testUnfixedKeyFollowsNowWhenNotDebugAndNotInMemory() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let now = try makeDate(
            year: 2026, month: 10, day: 28, hour: 15, minute: 0, second: 0, calendar: calendar
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: nil,
                inMemoryStore: false,
                isDebugBuild: false,
                now: now,
                calendar: calendar
            ),
            "2026-10-28"
        )
    }

    /// 同じ条件のまま now が日付をまたぐと、キーも翌日になる。
    func testUnfixedKeyMovesAcrossMidnight() throws {
        let calendar = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let beforeMidnight = try makeDate(
            year: 2026, month: 10, day: 27, hour: 23, minute: 59, second: 59, calendar: calendar
        )
        let afterMidnight = try makeDate(
            year: 2026, month: 10, day: 28, hour: 0, minute: 0, second: 0, calendar: calendar
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: nil,
                inMemoryStore: false,
                isDebugBuild: false,
                now: beforeMidnight,
                calendar: calendar
            ),
            "2026-10-27"
        )
        XCTAssertEqual(
            TodayKeyResolver.resolve(
                fixedDayKey: nil,
                inMemoryStore: false,
                isDebugBuild: false,
                now: afterMidnight,
                calendar: calendar
            ),
            "2026-10-28"
        )
    }

    /// 同じ瞬間でも、東京とロサンゼルス（夏時間のある地域）では日付キーが違う。
    func testSameInstantDiffersBetweenTokyoAndLosAngeles() throws {
        let tokyo = try makeCalendar(timeZoneIdentifier: "Asia/Tokyo")
        let losAngeles = try makeCalendar(timeZoneIdentifier: "America/Los_Angeles")
        let now = try makeDate(
            year: 2026, month: 10, day: 28, hour: 1, minute: 0, second: 0, calendar: tokyo
        )
        let tokyoKey = TodayKeyResolver.resolve(
            fixedDayKey: nil,
            inMemoryStore: false,
            isDebugBuild: false,
            now: now,
            calendar: tokyo
        )
        let losAngelesKey = TodayKeyResolver.resolve(
            fixedDayKey: nil,
            inMemoryStore: false,
            isDebugBuild: false,
            now: now,
            calendar: losAngeles
        )
        XCTAssertEqual(tokyoKey, "2026-10-28")
        XCTAssertEqual(losAngelesKey, "2026-10-27")
        XCTAssertNotEqual(tokyoKey, losAngelesKey)
    }

    private func makeCalendar(timeZoneIdentifier: String) throws -> Calendar {
        if timeZoneIdentifier == "UTC" {
            let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
            return DateKey.makeCalendar(timeZone: timeZone)
        }
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
