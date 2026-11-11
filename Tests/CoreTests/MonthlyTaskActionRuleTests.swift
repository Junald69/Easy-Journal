import XCTest
@testable import EasyJournal

/// 1行の保存のあと、タスク操作を続けてよいか。保存しない。画面を使わない。
final class MonthlyTaskActionRuleTests: XCTestCase {
    /// 保存の成否と、そのあとの読み込み失敗の組み合わせ。
    ///
    /// 保存は成功しても、読み込みに失敗したときは続けない。
    func testMayProceedAfterLogSave() {
        struct Row {
            let name: String
            let logSaveSucceeded: Bool
            let loadFailed: Bool
            let mayProceed: Bool
        }

        let rows = [
            Row(
                name: "保存失敗、読み込みはできている",
                logSaveSucceeded: false,
                loadFailed: false,
                mayProceed: false
            ),
            Row(
                name: "保存失敗、読み込みも失敗",
                logSaveSucceeded: false,
                loadFailed: true,
                mayProceed: false
            ),
            Row(
                name: "保存成功、読み込み失敗",
                logSaveSucceeded: true,
                loadFailed: true,
                mayProceed: false
            ),
            Row(
                name: "保存成功、読み込み成功",
                logSaveSucceeded: true,
                loadFailed: false,
                mayProceed: true
            ),
        ]

        for row in rows {
            let proceed = MonthlyTaskActionRule.mayProceedAfterLogSave(
                logSaveSucceeded: row.logSaveSucceeded,
                loadFailed: row.loadFailed
            )
            XCTAssertEqual(proceed, row.mayProceed, row.name)
        }
    }
}
