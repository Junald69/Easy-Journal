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
    ///
    /// タスク欄は、保存の前に見終わっている。ここでは見ない。
    func testPhaseAfterLogSaveMatchesTaskActionRule() {
        struct Row {
            let name: String
            let logSaveSucceeded: Bool
            let loadFailed: Bool
            let phase: MonthMoveRule.AfterLogSave
        }

        let rows = [
            Row(
                name: "保存失敗",
                logSaveSucceeded: false,
                loadFailed: false,
                phase: .stayAfterLogFailure
            ),
            Row(
                name: "保存成功、読み込み失敗",
                logSaveSucceeded: true,
                loadFailed: true,
                phase: .stayAfterLogFailure
            ),
            Row(
                name: "保存成功、読み込み成功",
                logSaveSucceeded: true,
                loadFailed: false,
                phase: .prepareDestination
            ),
        ]

        for row in rows {
            let phase = MonthMoveRule.phaseAfterLogSave(
                logSaveSucceeded: row.logSaveSucceeded,
                loadFailed: row.loadFailed
            )
            XCTAssertEqual(phase, row.phase, row.name)
            if phase == .stayAfterLogFailure {
                XCTAssertFalse(MonthMoveRule.mayDiscardLogDraft(phase), row.name)
            }
        }
    }

    /// 削除の確認、タスク欄、1行の保存、の順。タスク欄は保存より前。
    func testPhaseBeforeSaveChecksTaskDraftBeforeLogSave() {
        XCTAssertEqual(
            MonthMoveRule.phaseBeforeSideEffects(
                isEditingLog: true,
                needsDeleteConfirmation: true,
                taskDraft: "残すタスク"
            ),
            .confirmDelete
        )
        XCTAssertEqual(
            MonthMoveRule.phaseBeforeSideEffects(
                isEditingLog: true,
                needsDeleteConfirmation: false,
                taskDraft: "年賀状"
            ),
            .keepTaskDraft
        )
        XCTAssertEqual(
            MonthMoveRule.phaseBeforeSideEffects(
                isEditingLog: true,
                needsDeleteConfirmation: false,
                taskDraft: " \n "
            ),
            .saveLog
        )
        XCTAssertEqual(
            MonthMoveRule.phaseBeforeSideEffects(
                isEditingLog: false,
                needsDeleteConfirmation: false,
                taskDraft: ""
            ),
            .prepareDestination
        )
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
        XCTAssertFalse(outcome.showsTaskDraftBlockMessage)
        XCTAssertFalse(outcome.blockedBySaveOrLoad)
        XCTAssertEqual(outcome.moveProblem, .none)
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
        XCTAssertTrue(outcome.showsTaskDraftBlockMessage)
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
        XCTAssertEqual(outcome.moveProblem, .save)
        XCTAssertNotEqual(outcome.moveProblem, .load)
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
        XCTAssertEqual(outcome.moveProblem, .load)
        XCTAssertNotEqual(outcome.moveProblem, .save)
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

    /// 1行の編集中にタスク欄へ未確定の文字があるときは、1行を保存しない。編集も閉じない。
    ///
    /// 保存の成否は見ない。保存の前に止まる。ページ保存の失敗フラグも、ここでは使わない。
    func testTaskDraftBlocksBeforeLogSaveAndKeepsEditState() {
        let outcome = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            isEditingLog: true,
            logDraft: "日記",
            logSaveSucceeded: false,
            taskDraft: "未確定",
            pageSaveSucceeded: false,
            destinationLoadSucceeded: false
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertEqual(outcome.logDraft, "日記")
        XCTAssertTrue(outcome.isEditingLog)
        XCTAssertEqual(outcome.taskDraft, "未確定")
        XCTAssertTrue(outcome.showsTaskDraftBlockMessage)
        XCTAssertFalse(outcome.showsDeleteConfirmation)
        XCTAssertFalse(outcome.blockedBySaveOrLoad)
        XCTAssertEqual(outcome.moveProblem, .none)
    }

    /// 成功した移動は、前の失敗表示を消す。新しい失敗は、前の種類を置き換える。
    func testMoveProblemReplacesThePreviousFailure() {
        XCTAssertEqual(MonthMoveRule.replacing(previous: .load, with: .save), .save)
        XCTAssertEqual(MonthMoveRule.replacing(previous: .save, with: .load), .load)
        XCTAssertEqual(MonthMoveRule.replacing(previous: .load, with: .none), .none)
        XCTAssertEqual(
            MonthMoveRule.problemAfterPrepare(pageSaveSucceeded: true, destinationLoadSucceeded: true),
            .none
        )
        XCTAssertEqual(
            MonthMoveRule.problemAfterPrepare(pageSaveSucceeded: false, destinationLoadSucceeded: false),
            .save
        )
    }

    /// 12月の次は翌年1月。1月の前は前年12月。移れたときは下書きを残さない。
    func testResultCrossesYearAndComesBack() {
        let forward = MonthMoveRule.result(of: attempt(
            current: "2026-12",
            destination: "2027-01",
            isEditingLog: true,
            logDraft: "大晦日",
            logSaveSucceeded: true
        ))
        XCTAssertEqual(forward.monthKey, "2027-01")
        XCTAssertEqual(forward.logDraft, "")
        XCTAssertFalse(forward.isEditingLog)
        XCTAssertEqual(forward.moveProblem, .none)

        let backward = MonthMoveRule.result(of: attempt(
            current: "2027-01",
            destination: "2026-12"
        ))
        XCTAssertEqual(backward.monthKey, "2026-12")
        XCTAssertEqual(backward.moveProblem, .none)
    }

    /// 1行の保存先は、編集を始めた日付。開いている月が違っても、日付は作り直さない。
    func testLogSaveTargetStaysOnTheEditedDate() {
        XCTAssertEqual(MonthMoveRule.logSaveDateKey(editingDateKey: "2026-10-03"), "2026-10-03")
        XCTAssertNil(MonthMoveRule.logSaveDateKey(editingDateKey: "2026-10"))
        XCTAssertEqual(
            MonthMoveRule.taskSaveMonthKey(anchorMonthKey: "2026-10", displayedMonthKey: "2026-11"),
            "2026-10"
        )
        XCTAssertEqual(
            MonthMoveRule.taskSaveMonthKey(anchorMonthKey: nil, displayedMonthKey: "2026-11"),
            "2026-11"
        )
    }

    /// Router が先に月を変えても、下書きは書き始めた日付と月に残す。別の月へは書かない。
    func testExternalMonthChangeKeepsDraftsOnTheirSource() {
        let commit = MonthMoveRule.externalMonthPlan(
            loadedMonthKey: "2026-10",
            routerMonthKey: "2026-11",
            editingDateKey: "2026-10-26",
            needsDeleteConfirmation: false,
            taskDraft: "年賀状",
            taskDraftMonthKey: "2026-10"
        )
        XCTAssertEqual(commit.log, .commit(dateKey: "2026-10-26"))
        XCTAssertEqual(commit.task, .keep(monthKey: "2026-10"))

        let confirm = MonthMoveRule.externalMonthPlan(
            loadedMonthKey: "2026-10",
            routerMonthKey: "2027-01",
            editingDateKey: "2026-10-24",
            needsDeleteConfirmation: true,
            taskDraft: "  ",
            taskDraftMonthKey: nil
        )
        XCTAssertEqual(confirm.log, .confirmDelete(dateKey: "2026-10-24"))
        XCTAssertEqual(confirm.task, .none)

        let anchored = MonthMoveRule.externalMonthPlan(
            loadedMonthKey: "2026-10",
            routerMonthKey: "2026-11",
            editingDateKey: nil,
            needsDeleteConfirmation: false,
            taskDraft: "未確定",
            taskDraftMonthKey: nil
        )
        XCTAssertEqual(anchored.log, .none)
        XCTAssertEqual(anchored.task, .keep(monthKey: "2026-10"))

        let same = MonthMoveRule.externalMonthPlan(
            loadedMonthKey: "2026-11",
            routerMonthKey: "2026-11",
            editingDateKey: "2026-11-01",
            needsDeleteConfirmation: false,
            taskDraft: "残す",
            taskDraftMonthKey: "2026-10"
        )
        XCTAssertEqual(same.log, .none)
        XCTAssertEqual(same.task, .none)
    }

    /// フォーカスが外れたときも、削除の確認を先に、タスク欄を保存より前に見る。
    func testFocusLossKeepsLogWhenTaskDraftIsUncommitted() {
        XCTAssertEqual(
            MonthMoveRule.logFocusLoss(needsDeleteConfirmation: true, taskDraft: "年賀状"),
            .confirmDelete
        )
        XCTAssertEqual(
            MonthMoveRule.logFocusLoss(needsDeleteConfirmation: false, taskDraft: "年賀状"),
            .keepForTaskDraft
        )
        XCTAssertEqual(
            MonthMoveRule.logFocusLoss(needsDeleteConfirmation: false, taskDraft: " \n "),
            .save
        )
    }

    private func attempt(
        current: String = "2026-10",
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
            currentMonthKey: current,
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
