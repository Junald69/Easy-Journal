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

    /// タイトルと中身は、1つの値を入れ替えたときだけ一緒に変わる。
    func testMonthDisplayStateReplacesMonthAndContentTogether() {
        let october = MonthDisplayState(
            monthKey: "2026-10",
            textByDateKey: ["2026-10-26": "下書き"],
            dailyDateKeys: ["2026-10-27"]
        )
        let content = MonthlyLogContent(
            textByDateKey: ["2026-11-01": "翌月"],
            dailyDateKeys: []
        )
        let november = october.replaced(with: content, monthKey: "2026-11")
        XCTAssertEqual(november.monthKey, "2026-11")
        XCTAssertEqual(november.textByDateKey["2026-11-01"], "翌月")
        XCTAssertNil(november.textByDateKey["2026-10-26"])
        XCTAssertTrue(november.dailyDateKeys.isEmpty)
        XCTAssertEqual(october.monthKey, "2026-10")
        XCTAssertEqual(october.textByDateKey["2026-10-26"], "下書き")
        XCTAssertEqual(october.dailyDateKeys, ["2026-10-27"])
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

    /// 成功した移動は失敗を出さない。新しい失敗は、保存を読み込みより先に残す。
    func testMoveProblemReplacesThePreviousFailure() {
        XCTAssertEqual(
            MonthMoveRule.problemAfterPrepare(pageSaveSucceeded: false, destinationLoadSucceeded: true),
            .save
        )
        XCTAssertEqual(
            MonthMoveRule.problemAfterPrepare(pageSaveSucceeded: true, destinationLoadSucceeded: false),
            .load
        )
        XCTAssertEqual(
            MonthMoveRule.problemAfterPrepare(pageSaveSucceeded: true, destinationLoadSucceeded: true),
            .none
        )
        XCTAssertEqual(
            MonthMoveRule.problemAfterPrepare(pageSaveSucceeded: false, destinationLoadSucceeded: false),
            .save
        )
        let replaced = MonthMoveRule.result(of: attempt(
            destination: "2026-11",
            pageSaveSucceeded: false
        ))
        XCTAssertEqual(replaced.moveProblem, .save)
        XCTAssertEqual(replaced.monthKey, "2026-10")
        let cleared = MonthMoveRule.result(of: attempt(destination: "2026-11"))
        XCTAssertEqual(cleared.moveProblem, .none)
        XCTAssertEqual(cleared.monthKey, "2026-11")
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
        XCTAssertNil(MonthMoveRule.logSaveDateKey(editingDateKey: ""))
    }

    /// 外から頼まれた月も、◀▶ と同じ結果になる。隣の月でなくても同じ。
    ///
    /// 保存に失敗したら下書きと月を残す。タスク欄と削除確認は、保存より前に止める。
    /// 12月から1月、1月から12月も、この結果で決まる。
    func testRequestedMonthFollowsTheSameMoveResult() {
        let saved = MonthMoveRule.result(of: attempt(
            current: "2026-10",
            destination: "2026-12",
            isEditingLog: true,
            logDraft: "残す",
            logSaveSucceeded: true
        ))
        XCTAssertEqual(saved.monthKey, "2026-12")
        XCTAssertEqual(saved.logDraft, "")
        XCTAssertFalse(saved.isEditingLog)
        XCTAssertEqual(saved.taskDraft, "")

        let failedSave = MonthMoveRule.result(of: attempt(
            current: "2026-12",
            destination: "2027-01",
            isEditingLog: true,
            logDraft: "下書き",
            logSaveSucceeded: false
        ))
        XCTAssertEqual(failedSave.monthKey, "2026-12")
        XCTAssertEqual(failedSave.logDraft, "下書き")
        XCTAssertTrue(failedSave.isEditingLog)
        XCTAssertTrue(failedSave.blockedBySaveOrLoad)
        XCTAssertFalse(failedSave.showsDeleteConfirmation)

        let task = MonthMoveRule.result(of: attempt(
            current: "2027-01",
            destination: "2026-12",
            isEditingLog: true,
            logDraft: "元日",
            logSaveSucceeded: false,
            taskDraft: "未確定",
            pageSaveSucceeded: false
        ))
        XCTAssertEqual(task.monthKey, "2027-01")
        XCTAssertEqual(task.logDraft, "元日")
        XCTAssertTrue(task.isEditingLog)
        XCTAssertEqual(task.taskDraft, "未確定")
        XCTAssertTrue(task.showsTaskDraftBlockMessage)
        XCTAssertFalse(task.blockedBySaveOrLoad)

        let confirm = MonthMoveRule.result(of: attempt(
            current: "2026-10",
            destination: "2026-11",
            isEditingLog: true,
            needsDeleteConfirmation: true,
            logDraft: "   ",
            taskDraft: "残すタスク"
        ))
        XCTAssertEqual(confirm.monthKey, "2026-10")
        XCTAssertEqual(confirm.logDraft, "   ")
        XCTAssertEqual(confirm.taskDraft, "残すタスク")
        XCTAssertTrue(confirm.showsDeleteConfirmation)
        XCTAssertFalse(confirm.blockedBySaveOrLoad)
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
