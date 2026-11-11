import XCTest
@testable import EasyJournal

/// 月を移る前の判定。保存しない。画面を使わない。
final class MonthMoveRuleTests: XCTestCase {
    /// 10月→11月→10月、12月→翌年1月、1月→前年12月。
    func testDestinationStepsAcrossMonthsAndYears() {
        XCTAssertEqual(MonthMoveRule.destination(from: "2026-10", goingForward: true), "2026-11")
        XCTAssertEqual(MonthMoveRule.destination(from: "2026-11", goingForward: false), "2026-10")
        XCTAssertEqual(MonthMoveRule.destination(from: "2026-12", goingForward: true), "2027-01")
        XCTAssertEqual(MonthMoveRule.destination(from: "2027-01", goingForward: false), "2026-12")
        XCTAssertNil(MonthMoveRule.destination(from: "2026-13", goingForward: true))
        XCTAssertNil(MonthMoveRule.destination(from: "", goingForward: false))
    }

    /// 保存の成否と、そのあとの読み込み失敗で、月を止めるか。
    func testPhaseAfterLogSaveMatchesTaskActionRule() {
        struct Row {
            let name: String
            let logSaveSucceeded: Bool
            let loadFailed: Bool
            let taskDraft: String
            let phase: MonthMoveRule.Phase
        }

        let rows = [
            Row(
                name: "保存失敗",
                logSaveSucceeded: false,
                loadFailed: false,
                taskDraft: "",
                phase: .stayAfterLogFailure
            ),
            Row(
                name: "保存成功、読み込み失敗",
                logSaveSucceeded: true,
                loadFailed: true,
                taskDraft: "",
                phase: .stayAfterLogFailure
            ),
            Row(
                name: "保存成功、タスク欄に文字",
                logSaveSucceeded: true,
                loadFailed: false,
                taskDraft: "年賀状",
                phase: .keepTaskDraft
            ),
            Row(
                name: "保存成功、タスク欄は空白だけ",
                logSaveSucceeded: true,
                loadFailed: false,
                taskDraft: " \n ",
                phase: .prepareDestination
            ),
        ]

        for row in rows {
            let phase = MonthMoveRule.phaseAfterLogSave(
                logSaveSucceeded: row.logSaveSucceeded,
                loadFailed: row.loadFailed,
                taskDraft: row.taskDraft
            )
            XCTAssertEqual(phase, row.phase, row.name)
            if phase == .stayAfterLogFailure {
                XCTAssertFalse(MonthMoveRule.mayDiscardLogDraft(phase), row.name)
            }
        }
    }

    /// 文章を空にした下書きは、確認を出すだけで、月も文字も変えない。
    func testEmptiedDraftNeedsConfirmationAndDoesNotMove() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            isEditingLog: true,
            needsDeleteConfirmation: true,
            logDraft: "   ",
            taskDraft: "残すタスク"
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertEqual(outcome.logDraft, "   ")
        XCTAssertTrue(outcome.isEditingLog)
        XCTAssertEqual(outcome.taskDraft, "残すタスク")
        XCTAssertTrue(outcome.showsDeleteConfirmation)
        XCTAssertFalse(outcome.blockedBySaveOrLoad)
        XCTAssertFalse(MonthMoveRule.mayDiscardLogDraft(.confirmDelete))
    }

    /// 1行の保存に失敗したら、入力を残して月は移さない。
    func testLogSaveFailureKeepsDraftAndCancelsMove() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            isEditingLog: true,
            logDraft: "新しい",
            logSaveSucceeded: false
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertEqual(outcome.logDraft, "新しい")
        XCTAssertTrue(outcome.isEditingLog)
        XCTAssertTrue(outcome.blockedBySaveOrLoad)
        XCTAssertFalse(outcome.showsDeleteConfirmation)
    }

    /// 1行は保存できても、そのあとの読み込みに失敗したら、入力を残して月は移さない。
    func testReloadFailureKeepsDraftAndCancelsMove() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2027-01",
            isEditingLog: true,
            logDraft: "残す",
            logSaveSucceeded: true,
            loadFailed: true
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertEqual(outcome.logDraft, "残す")
        XCTAssertTrue(outcome.isEditingLog)
        XCTAssertTrue(outcome.blockedBySaveOrLoad)
    }

    /// タスクの追加欄に未確定の文字があるときは、その文字を残して月は移さない。
    func testUncommittedTaskDraftStaysAndDoesNotMove() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            taskDraft: "  年賀状  "
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertEqual(outcome.taskDraft, "  年賀状  ")
        XCTAssertFalse(outcome.isEditingLog)
        XCTAssertFalse(outcome.blockedBySaveOrLoad)
        XCTAssertFalse(outcome.showsDeleteConfirmation)
    }

    /// 空白だけの追加欄は、未確定の文字とはみなさない。移れたときは欄を空にする。
    func testWhitespaceTaskDraftDoesNotBlockMove() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            taskDraft: " \n\t "
        ))
        XCTAssertEqual(outcome.monthKey, "2026-11")
        XCTAssertEqual(outcome.taskDraft, "")
        XCTAssertFalse(outcome.blockedBySaveOrLoad)
    }

    /// 移る先の保存に失敗したら、月は移さない。
    func testPageSaveFailureCancelsMove() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2027-01",
            pageSaveSucceeded: false
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertTrue(outcome.blockedBySaveOrLoad)
        XCTAssertFalse(MonthMoveRule.shouldCommitMove(
            pageSaveSucceeded: false,
            destinationLoadSucceeded: true
        ))
    }

    /// 移る先を読めなかったら、月は移さない。
    func testDestinationLoadFailureCancelsMove() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-12",
            destinationLoadSucceeded: false
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertTrue(outcome.blockedBySaveOrLoad)
        XCTAssertFalse(MonthMoveRule.shouldCommitMove(
            pageSaveSucceeded: true,
            destinationLoadSucceeded: false
        ))
    }

    /// 障害が無いときは移る。1行とタスク欄の下書きは、移った先へ残さない。
    func testReadyMoveClearsDrafts() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            isEditingLog: true,
            logDraft: "保存される",
            logSaveSucceeded: true,
            taskDraft: "   "
        ))
        XCTAssertEqual(outcome.monthKey, "2026-11")
        XCTAssertEqual(outcome.logDraft, "")
        XCTAssertFalse(outcome.isEditingLog)
        XCTAssertEqual(outcome.taskDraft, "")
        XCTAssertFalse(outcome.blockedBySaveOrLoad)
    }

    /// 1行を保存したあとにタスク欄が残っているときは、1行だけ閉じて月は移さない。
    func testSavedLogStillKeepsTaskDraftOnCurrentMonth() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            isEditingLog: true,
            logDraft: "日記",
            logSaveSucceeded: true,
            taskDraft: "未確定"
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertEqual(outcome.logDraft, "")
        XCTAssertFalse(outcome.isEditingLog)
        XCTAssertEqual(outcome.taskDraft, "未確定")
    }

    private func attempt(
        destination: String?,
        isEditingLog: Bool = false,
        needsDeleteConfirmation: Bool = false,
        logDraft: String = "",
        logSaveSucceeded: Bool = true,
        loadFailed: Bool = false,
        taskDraft: String = "",
        pageSaveSucceeded: Bool = true,
        destinationLoadSucceeded: Bool = true
    ) -> MonthMoveRule.Attempt {
        MonthMoveRule.Attempt(
            currentMonthKey: "2026-10",
            destinationMonthKey: destination,
            isEditingLog: isEditingLog,
            needsDeleteConfirmation: needsDeleteConfirmation,
            logDraft: logDraft,
            logSaveSucceeded: logSaveSucceeded,
            loadFailed: loadFailed,
            taskDraft: taskDraft,
            pageSaveSucceeded: pageSaveSucceeded,
            destinationLoadSucceeded: destinationLoadSucceeded
        )
    }
}
