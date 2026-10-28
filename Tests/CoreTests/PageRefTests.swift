import XCTest
@testable import EasyJournal

/// ページ指定の文字列。往復して同じになることと、不正な文字列が nil であることを見る。
final class PageRefTests: XCTestCase {
    func testRoundTripKeepsTheSameText() {
        let samples: [(String, PageRef)] = [
            ("monthly:2026-10", .monthlyLog(monthKey: "2026-10")),
            ("tracker:2026-10", .monthlyTracker(monthKey: "2026-10")),
            ("daily:2026-10-27", .daily(dateKey: "2026-10-27")),
            ("monthly:2027-01", .monthlyLog(monthKey: "2027-01")),
            ("tracker:2027-01", .monthlyTracker(monthKey: "2027-01")),
            ("daily:2027-01-01", .daily(dateKey: "2027-01-01")),
        ]
        for (text, expected) in samples {
            let parsed = PageRef(openPage: text)
            XCTAssertEqual(parsed, Optional(expected), text)
            XCTAssertEqual(expected.openPageText, text)
            XCTAssertEqual(parsed?.openPageText, Optional(text))
            if let parsed {
                XCTAssertEqual(PageRef(openPage: parsed.openPageText), Optional(parsed), text)
            }
        }
        XCTAssertNotEqual(
            PageRef(openPage: "monthly:2026-10"),
            PageRef(openPage: "tracker:2026-10")
        )
    }

    func testInvalidTextReturnsNil() {
        let invalid = [
            "",
            "daily:",
            "daily:2026-13-01",
            "daily:2026-02-30",
            "monthly:2026-13",
            "foo:2026-10",
            "daily:2026-10",
            " daily:2026-10-27",
            "daily:2026-10-27 ",
            "daily:2026-02-29",
            "Daily:2026-10-27",
            "monthly:2026-10-27",
            "tracker:2026-10-27",
            "tracker:2026-13",
            "monthly:2026-1",
            "daily:2026-1-01",
            "monthly:",
            "tracker:",
            ":",
            "daily:2026-10-27:00",
            "monthly:2026-10:01",
            "daily:2026-00-10",
            "monthly:2026-00",
            "   ",
            "\u{3000}daily:2026-10-27",
        ]
        for text in invalid {
            XCTAssertNil(PageRef(openPage: text), text)
        }
    }

    func testLeapDay() {
        XCTAssertEqual(
            PageRef(openPage: "daily:2028-02-29"),
            Optional(PageRef.daily(dateKey: "2028-02-29"))
        )
        XCTAssertEqual(PageRef.daily(dateKey: "2028-02-29").openPageText, "daily:2028-02-29")
        XCTAssertNil(PageRef(openPage: "daily:2026-02-29"))
        XCTAssertEqual(
            PageRef(openPage: "monthly:2028-02"),
            Optional(PageRef.monthlyLog(monthKey: "2028-02"))
        )
        XCTAssertEqual(
            PageRef(openPage: "tracker:2028-02"),
            Optional(PageRef.monthlyTracker(monthKey: "2028-02"))
        )
    }
}
