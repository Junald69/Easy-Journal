import Foundation
import XCTest
@testable import EasyJournal

/// 月の行のルール。保存先は使わない。画面も使わない。
final class MonthlyLogRowsTests: XCTestCase {
    /// 2026年10月は31行。1日は木曜。3日と4日は土日。最後は31日。
    func testOctober2026HasThirtyOneRows() {
        let rows = makeOctober(todayKey: "2026-10-27")
        XCTAssertEqual(rows.count, 31)
        XCTAssertEqual(rows.map(\.dateKey), DateKey.dayKeys(inMonth: "2026-10"))
        guard rows.count == 31 else {
            return
        }

        XCTAssertEqual(rows[0].dateKey, "2026-10-01")
        XCTAssertEqual(rows[0].dayNumber, 1)
        XCTAssertEqual(rows[0].weekday, .thursday)
        XCTAssertFalse(rows[0].isWeekend)
        XCTAssertEqual(rows[0].text, "")
        XCTAssertFalse(rows[0].hasDaily)

        XCTAssertEqual(rows[1].dateKey, "2026-10-02")
        XCTAssertEqual(rows[1].weekday, .friday)
        XCTAssertFalse(rows[1].isWeekend)

        XCTAssertEqual(rows[2].dateKey, "2026-10-03")
        XCTAssertEqual(rows[2].dayNumber, 3)
        XCTAssertEqual(rows[2].weekday, .saturday)
        XCTAssertTrue(rows[2].isWeekend)

        XCTAssertEqual(rows[3].dateKey, "2026-10-04")
        XCTAssertEqual(rows[3].dayNumber, 4)
        XCTAssertEqual(rows[3].weekday, .sunday)
        XCTAssertTrue(rows[3].isWeekend)

        XCTAssertEqual(rows[4].weekday, .monday)
        XCTAssertFalse(rows[4].isWeekend)

        XCTAssertEqual(rows[30].dateKey, "2026-10-31")
        XCTAssertEqual(rows[30].dayNumber, 31)
        XCTAssertEqual(rows[30].weekday, .saturday)
        XCTAssertTrue(rows[30].isWeekend)

        var todayKeys: [String] = []
        for row in rows {
            if row.isToday {
                todayKeys.append(row.dateKey)
            }
            let weekend = row.weekday == .saturday || row.weekday == .sunday
            XCTAssertEqual(row.isWeekend, weekend, row.dateKey)
        }
        XCTAssertEqual(todayKeys, ["2026-10-27"])
    }

    /// うるう年の2月は29行。平年の2月は28行。不正な月は空。
    func testFebruaryRowCounts() {
        let leap = MonthlyLogRows.make(
            monthKey: "2028-02",
            textByDateKey: [:],
            dailyDateKeys: [],
            todayKey: "2028-02-29"
        )
        XCTAssertEqual(leap.count, 29)
        guard leap.count == 29 else {
            return
        }
        XCTAssertEqual(leap.first?.dateKey, "2028-02-01")
        XCTAssertEqual(leap.first?.dayNumber, 1)
        XCTAssertEqual(leap.last?.dateKey, "2028-02-29")
        XCTAssertEqual(leap.last?.dayNumber, 29)
        XCTAssertEqual(leap.filter(\.isToday).map(\.dateKey), ["2028-02-29"])

        let common = MonthlyLogRows.make(
            monthKey: "2027-02",
            textByDateKey: [:],
            dailyDateKeys: [],
            todayKey: "2027-02-28"
        )
        XCTAssertEqual(common.count, 28)
        guard common.count == 28 else {
            return
        }
        XCTAssertEqual(common.first?.dateKey, "2027-02-01")
        XCTAssertEqual(common.last?.dateKey, "2027-02-28")
        XCTAssertEqual(common.last?.dayNumber, 28)
        XCTAssertFalse(common.contains { row in row.dateKey == "2027-02-29" })

        let invalid = MonthlyLogRows.make(
            monthKey: "2026-13",
            textByDateKey: ["2026-13-01": "x"],
            dailyDateKeys: ["2026-13-01"],
            todayKey: "2026-13-01"
        )
        XCTAssertEqual(invalid.count, 0)
    }

    /// 今日がその月に無いときは、今日の行は無い。全部 false。
    func testTodayFlagOnlyWhenThatDayIsInTheMonth() {
        let outside = makeOctober(todayKey: "2026-11-01")
        XCTAssertEqual(outside.count, 31)
        for row in outside {
            XCTAssertFalse(row.isToday, row.dateKey)
        }

        let emptyToday = makeOctober(todayKey: "")
        for row in emptyToday {
            XCTAssertFalse(row.isToday, row.dateKey)
        }
    }

    /// 文章がある日、空の日、Daily の印。月の外の日付キーは無視する。
    func testTextDailyMarksAndKeysOutsideTheMonth() {
        let rows = MonthlyLogRows.make(
            monthKey: "2026-10",
            textByDateKey: [
                "2026-10-01": "月初",
                "2026-10-08": "長い文章",
                "2026-11-01": "来月",
                "nope": "壊れた",
                "2026-10-32": "無い日",
            ],
            dailyDateKeys: ["2026-10-27", "2026-09-30", "bad"],
            todayKey: "2026-10-02"
        )
        XCTAssertEqual(rows.count, 31)
        guard rows.count == 31 else {
            return
        }
        XCTAssertEqual(rows[0].text, "月初")
        XCTAssertFalse(rows[0].hasDaily)
        XCTAssertEqual(rows[7].dateKey, "2026-10-08")
        XCTAssertEqual(rows[7].text, "長い文章")
        XCTAssertFalse(rows[7].hasDaily)
        XCTAssertEqual(rows[1].dateKey, "2026-10-02")
        XCTAssertEqual(rows[1].text, "")
        XCTAssertFalse(rows[1].hasDaily)
        XCTAssertTrue(rows[1].isToday)
        XCTAssertEqual(rows[26].dateKey, "2026-10-27")
        XCTAssertEqual(rows[26].text, "")
        XCTAssertTrue(rows[26].hasDaily)
        XCTAssertFalse(rows[26].isToday)

        for row in rows {
            XCTAssertNotEqual(row.text, "来月")
            XCTAssertNotEqual(row.text, "壊れた")
            XCTAssertNotEqual(row.text, "無い日")
            XCTAssertNotEqual(row.dateKey, "2026-11-01")
            XCTAssertNotEqual(row.dateKey, "2026-09-30")
            if row.dateKey != "2026-10-27" {
                XCTAssertFalse(row.hasDaily, row.dateKey)
            }
        }
    }

    private func makeOctober(todayKey: String) -> [MonthlyLogRow] {
        MonthlyLogRows.make(
            monthKey: "2026-10",
            textByDateKey: [:],
            dailyDateKeys: [],
            todayKey: todayKey
        )
    }
}
