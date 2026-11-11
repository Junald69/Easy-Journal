import XCTest
@testable import EasyJournal

/// タスク欄で止めたあとの保護。日記を閉じたら、保護も戻し先も消える。
final class LogEditorHoldStateTests: XCTestCase {
    /// 止めたあとタスクを追加したら、保護も戻し先も消える。
    func testBlockThenTaskAddedClearsHoldAndRestore() {
        var state = LogEditorHoldState()
        state.blockWhileEditing()
        state.beginRestore(dateKey: "2026-10-26")
        XCTAssertTrue(state.holdLogEditor)
        XCTAssertEqual(state.restoreLogFocusDateKey, "2026-10-26")

        state.taskAdded()
        XCTAssertFalse(state.holdLogEditor)
        XCTAssertNil(state.restoreLogFocusDateKey)
    }

    /// 編集している日が無くなったら、保護も戻し先も消える。
    func testEditingClosedClearsHoldAndRestore() {
        var state = LogEditorHoldState()
        state.blockWhileEditing()
        state.beginRestore(dateKey: "2026-10-26")

        state.editingClosed()
        XCTAssertFalse(state.holdLogEditor)
        XCTAssertNil(state.restoreLogFocusDateKey)
    }

    /// 止めが解けて、戻し先が無いときは保護を外す。戻し先があるときは残す。
    func testTaskBlockEndedKeepsHoldOnlyWhileRestoring() {
        var restoring = LogEditorHoldState()
        restoring.blockWhileEditing()
        restoring.beginRestore(dateKey: "2026-10-26")
        restoring.taskBlockEnded()
        XCTAssertTrue(restoring.holdLogEditor)
        XCTAssertEqual(restoring.restoreLogFocusDateKey, "2026-10-26")

        var finished = LogEditorHoldState()
        finished.blockWhileEditing()
        finished.taskBlockEnded()
        XCTAssertFalse(finished.holdLogEditor)
        XCTAssertNil(finished.restoreLogFocusDateKey)
    }
}
