import XCTest
@testable import EasyJournal

/// Index に出す月。空の月ページだけでは出さない。今月は記録が無くても出す。
final class IndexMonthListTests: XCTestCase {
    func testEmptyMonthPageIsHiddenUnlessItIsCurrent() {
        XCTAssertFalse(IndexMonthList.includes(IndexMonthList.Records()))
        XCTAssertTrue(IndexMonthList.includes(IndexMonthList.Records(isCurrentMonth: true)))
    }

    func testAnyRealRecordMakesTheMonthVisible() {
        XCTAssertTrue(IndexMonthList.includes(IndexMonthList.Records(hasLog: true)))
        XCTAssertTrue(IndexMonthList.includes(IndexMonthList.Records(hasMonthlyTask: true)))
        XCTAssertTrue(IndexMonthList.includes(IndexMonthList.Records(hasHabit: true)))
        XCTAssertTrue(IndexMonthList.includes(IndexMonthList.Records(hasSleep: true)))
        XCTAssertTrue(IndexMonthList.includes(IndexMonthList.Records(hasMood: true)))
        XCTAssertTrue(IndexMonthList.includes(IndexMonthList.Records(hasDaily: true)))
    }
}
