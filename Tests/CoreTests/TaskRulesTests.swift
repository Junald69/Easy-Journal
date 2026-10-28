import XCTest
@testable import EasyJournal

/// タスクの記号、タップ、繰越できるかのルール。保存は使わない。
final class TaskRulesTests: XCTestCase {
    /// 画面に出す文字そのもの。□ ◧ ■ □> ◧>
    func testSymbolTextMatchesDisplayCharacters() {
        XCTAssertEqual(TaskRules.Symbol.open.text, "□")
        XCTAssertEqual(TaskRules.Symbol.partial.text, "◧")
        XCTAssertEqual(TaskRules.Symbol.done.text, "■")
        XCTAssertEqual(TaskRules.Symbol.openCarried.text, "□>")
        XCTAssertEqual(TaskRules.Symbol.partialCarried.text, "◧>")
    }

    /// 進み具合3つ × 繰越ありなしの6通り。
    /// 記号、タップ後、繰越できるか、取り消せるか、組み合わせが正しいか、タップできるか。
    func testAllSixCombinations() {
        struct Row {
            let progress: TaskProgress
            let isCarriedForward: Bool
            let symbol: TaskRules.Symbol?
            let text: String?
            let afterTap: TaskProgress
            let canCarryForward: Bool
            let canCancelCarryForward: Bool
            let isValid: Bool
            let isTappable: Bool
        }

        let rows = [
            Row(
                progress: .open,
                isCarriedForward: false,
                symbol: .open,
                text: "□",
                afterTap: .partial,
                canCarryForward: true,
                canCancelCarryForward: false,
                isValid: true,
                isTappable: true
            ),
            Row(
                progress: .partial,
                isCarriedForward: false,
                symbol: .partial,
                text: "◧",
                afterTap: .done,
                canCarryForward: true,
                canCancelCarryForward: false,
                isValid: true,
                isTappable: true
            ),
            Row(
                progress: .done,
                isCarriedForward: false,
                symbol: .done,
                text: "■",
                afterTap: .open,
                canCarryForward: false,
                canCancelCarryForward: false,
                isValid: true,
                isTappable: true
            ),
            Row(
                progress: .open,
                isCarriedForward: true,
                symbol: .openCarried,
                text: "□>",
                afterTap: .open,
                canCarryForward: false,
                canCancelCarryForward: true,
                isValid: true,
                isTappable: false
            ),
            Row(
                progress: .partial,
                isCarriedForward: true,
                symbol: .partialCarried,
                text: "◧>",
                afterTap: .partial,
                canCarryForward: false,
                canCancelCarryForward: true,
                isValid: true,
                isTappable: false
            ),
            Row(
                progress: .done,
                isCarriedForward: true,
                symbol: nil,
                text: nil,
                afterTap: .done,
                canCarryForward: false,
                canCancelCarryForward: false,
                isValid: false,
                isTappable: false
            ),
        ]
        XCTAssertEqual(rows.count, 6)

        for row in rows {
            let label = "\(row.progress.rawValue) carried=\(row.isCarriedForward)"
            let symbol = TaskRules.symbol(
                progress: row.progress,
                isCarriedForward: row.isCarriedForward
            )
            XCTAssertEqual(symbol, row.symbol, label)
            XCTAssertEqual(symbol?.text, row.text, label)
            XCTAssertEqual(
                TaskRules.progressAfterTap(
                    progress: row.progress,
                    isCarriedForward: row.isCarriedForward
                ),
                row.afterTap,
                label
            )
            XCTAssertEqual(
                TaskRules.canCarryForward(
                    progress: row.progress,
                    isCarriedForward: row.isCarriedForward
                ),
                row.canCarryForward,
                label
            )
            XCTAssertEqual(
                TaskRules.canCancelCarryForward(
                    progress: row.progress,
                    isCarriedForward: row.isCarriedForward
                ),
                row.canCancelCarryForward,
                label
            )
            XCTAssertEqual(
                TaskRules.isValidCombination(
                    progress: row.progress,
                    isCarriedForward: row.isCarriedForward
                ),
                row.isValid,
                label
            )
            XCTAssertEqual(
                TaskRules.isTappable(
                    progress: row.progress,
                    isCarriedForward: row.isCarriedForward
                ),
                row.isTappable,
                label
            )
        }
    }

    /// 未繰越は3回タップすると元の進み具合に戻る。open → partial → done → open。
    func testThreeTapsReturnToOriginal() {
        XCTAssertEqual(TaskRules.nextProgress(.open), .partial)
        XCTAssertEqual(TaskRules.nextProgress(.partial), .done)
        XCTAssertEqual(TaskRules.nextProgress(.done), .open)

        let starts: [TaskProgress] = [.open, .partial, .done]
        for start in starts {
            let once = TaskRules.progressAfterTap(progress: start, isCarriedForward: false)
            let twice = TaskRules.progressAfterTap(progress: once, isCarriedForward: false)
            let thrice = TaskRules.progressAfterTap(progress: twice, isCarriedForward: false)
            XCTAssertEqual(thrice, start, start.rawValue)
        }

        var progress = TaskProgress.open
        progress = TaskRules.progressAfterTap(progress: progress, isCarriedForward: false)
        XCTAssertEqual(progress, .partial)
        progress = TaskRules.progressAfterTap(progress: progress, isCarriedForward: false)
        XCTAssertEqual(progress, .done)
        progress = TaskRules.progressAfterTap(progress: progress, isCarriedForward: false)
        XCTAssertEqual(progress, .open)
    }

    /// 繰越済みは、何回タップしても進み具合が変わらない。
    func testCarriedForwardProgressDoesNotChangeOnTap() {
        let carried: [TaskProgress] = [.open, .partial, .done]
        for progress in carried {
            var current = progress
            for _ in 0..<5 {
                current = TaskRules.progressAfterTap(progress: current, isCarriedForward: true)
                XCTAssertEqual(current, progress, progress.rawValue)
            }
            XCTAssertFalse(
                TaskRules.isTappable(progress: progress, isCarriedForward: true),
                progress.rawValue
            )
        }
    }

    /// 完了は繰越できない。繰越済みをもう一度繰越することもできない。
    func testDoneCannotBeCarriedForward() {
        XCTAssertFalse(TaskRules.canCarryForward(progress: .done, isCarriedForward: false))
        XCTAssertFalse(TaskRules.canCarryForward(progress: .done, isCarriedForward: true))
        XCTAssertFalse(TaskRules.canCarryForward(progress: .open, isCarriedForward: true))
        XCTAssertFalse(TaskRules.canCarryForward(progress: .partial, isCarriedForward: true))
        XCTAssertTrue(TaskRules.canCarryForward(progress: .open, isCarriedForward: false))
        XCTAssertTrue(TaskRules.canCarryForward(progress: .partial, isCarriedForward: false))
        XCTAssertNil(TaskRules.symbol(progress: .done, isCarriedForward: true))
        XCTAssertFalse(TaskRules.isValidCombination(progress: .done, isCarriedForward: true))
        XCTAssertFalse(TaskRules.canCancelCarryForward(progress: .done, isCarriedForward: true))
    }
}
