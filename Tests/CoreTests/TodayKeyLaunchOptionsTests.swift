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
    /// Release でテストを組み立てたときは、引数があっても普段の今日のまま。
    func testResolvedTodayKeyHonorsInMemoryAndValidDay() throws {
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let calendar = DateKey.makeCalendar(timeZone: timeZone)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = 2026
        components.month = 10
        components.day = 28
        components.hour = 12
        let now = try XCTUnwrap(calendar.date(from: components))
        XCTAssertEqual(DateKey.todayKey(now: now, calendar: calendar), "2026-10-28")

        let valid = LaunchOptions(arguments: ["EasyJournal", "-inMemoryStore", "-todayKey", "2026-10-27"])
        let invalid = LaunchOptions(arguments: ["EasyJournal", "-inMemoryStore", "-todayKey", "2026-10-32"])
        let onDisk = LaunchOptions(arguments: ["EasyJournal", "-todayKey", "2026-10-27"])

        #if DEBUG
        XCTAssertEqual(
            EasyJournalApp.resolvedTodayKey(options: valid, now: now, calendar: calendar),
            "2026-10-27"
        )
        XCTAssertEqual(
            EasyJournalApp.resolvedTodayKey(options: invalid, now: now, calendar: calendar),
            "2026-10-28"
        )
        XCTAssertEqual(
            EasyJournalApp.resolvedTodayKey(options: onDisk, now: now, calendar: calendar),
            "2026-10-28"
        )
        #else
        XCTAssertEqual(
            EasyJournalApp.resolvedTodayKey(options: valid, now: now, calendar: calendar),
            "2026-10-28"
        )
        XCTAssertEqual(
            EasyJournalApp.resolvedTodayKey(options: invalid, now: now, calendar: calendar),
            "2026-10-28"
        )
        XCTAssertEqual(
            EasyJournalApp.resolvedTodayKey(options: onDisk, now: now, calendar: calendar),
            "2026-10-28"
        )
        #endif
    }
}
