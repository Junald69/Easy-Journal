import Foundation

/// 月を移る前の判定。保存しない。画面を持たない。
///
/// 1行を片付ける条件は、月のタスクを触るときと同じ（`MonthlyTaskActionRule`）。
/// 保存に失敗したとき、そのあとの読み込みに失敗したときは、月を移さない。
/// 文章を空にして消す下書きは、確認の前に消さない。
/// タスクの追加欄に、空白以外の未確定の文字があるときも、月を移さない。文字は捨てない。
enum MonthMoveRule {
    /// ボタンを押した直後、保存するより前の段階。
    enum Phase: Equatable {
        /// 空にした1行の確認を出す。月は移さない。下書きは残す。
        case confirmDelete
        /// 編集中の1行を、今までと同じ保存で確定してから続きを見る。
        case saveLog
        /// 1行の保存か、そのあとの読み込みに失敗した。下書きを残して月は移さない。
        case stayAfterLogFailure
        /// タスク名の未確定の文字を残して、月は移さない。
        case keepTaskDraft
        /// 移る先の月ページを用意して、読めたときだけ移る。
        case prepareDestination
    }

    /// 1回の移動で、画面がどうなるかの結果。テストが、画面の手順と突き合わせる。
    struct Attempt: Equatable {
        var currentMonthKey: String
        /// 計算できなかったときは nil。月は動かない。
        var destinationMonthKey: String?
        var isEditingLog: Bool
        var needsDeleteConfirmation: Bool
        var logDraft: String
        /// 1行を保存したあとの戻り値。編集していないときは使わない。
        var logSaveSucceeded: Bool
        /// 1行の保存のあとの読み込みが失敗したか。編集していないときは使わない。
        var loadFailed: Bool
        var taskDraft: String
        /// 移る先の月ページの保存が成功したか。そこまで進まないときは使わない。
        var pageSaveSucceeded: Bool
        /// 移る先を読めたか。そこまで進まないときは使わない。
        var destinationLoadSucceeded: Bool
    }

    /// `result` が返す、移動のあと画面が覚えるもの。
    struct Result: Equatable {
        var monthKey: String
        var logDraft: String
        var isEditingLog: Bool
        var taskDraft: String
        /// 行を消す確認を出す。出しただけでは消さない。
        var showsDeleteConfirmation: Bool
        /// 保存か読み込みに失敗して、月を止めた。
        var blockedBySaveOrLoad: Bool
    }

    /// 前後のどちらか。不正な月キーなら nil。
    static func destination(from monthKey: String, goingForward: Bool) -> String? {
        if goingForward {
            return DateKey.nextMonthKey(after: monthKey)
        }
        return DateKey.previousMonthKey(before: monthKey)
    }

    /// 空白と改行を除いて文字が残るとき true。タスク名として保存できない空白だけは false。
    ///
    /// 除き方は、タスク追加が空とみなすときと同じ（前後の空白と改行）。
    static func hasUncommittedTaskDraft(_ draft: String) -> Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty == false
    }

    /// 保存するより前。削除の確認を、タスク欄より先に見る。
    static func phaseBeforeSideEffects(
        isEditingLog: Bool,
        needsDeleteConfirmation: Bool,
        taskDraft: String
    ) -> Phase {
        if isEditingLog && needsDeleteConfirmation {
            return .confirmDelete
        }
        if isEditingLog {
            return .saveLog
        }
        if hasUncommittedTaskDraft(taskDraft) {
            return .keepTaskDraft
        }
        return .prepareDestination
    }

    /// 1行を保存したあと。続けてよいかは `MonthlyTaskActionRule` に聞く。
    ///
    /// 保存に失敗したときも、保存のあとの読み込みに失敗したときも、月は移さない。
    /// どちらも、1行の下書きは捨てない。
    static func phaseAfterLogSave(
        logSaveSucceeded: Bool,
        loadFailed: Bool,
        taskDraft: String
    ) -> Phase {
        let mayContinue = MonthlyTaskActionRule.mayProceedAfterLogSave(
            logSaveSucceeded: logSaveSucceeded,
            loadFailed: loadFailed
        )
        if mayContinue == false {
            return .stayAfterLogFailure
        }
        if hasUncommittedTaskDraft(taskDraft) {
            return .keepTaskDraft
        }
        return .prepareDestination
    }

    /// 移る先のページ保存と読み込みが、どちらも成功したときだけ true。
    static func shouldCommitMove(pageSaveSucceeded: Bool, destinationLoadSucceeded: Bool) -> Bool {
        if pageSaveSucceeded == false {
            return false
        }
        if destinationLoadSucceeded == false {
            return false
        }
        return true
    }

    /// この段階で、1行の下書きを画面から消してよいか。
    ///
    /// 保存も読み込みも成功したあとの段階だけ true。
    /// 確認の前、保存の前、失敗したあとは false。入力を残す。
    static func mayDiscardLogDraft(_ phase: Phase) -> Bool {
        switch phase {
        case .prepareDestination, .keepTaskDraft:
            return true
        case .confirmDelete, .saveLog, .stayAfterLogFailure:
            return false
        }
    }

    /// 画面の手順と同じ順で、移動の結果を返す。
    ///
    /// 失敗したときは、開いている月と1行の下書きを変えない。
    /// タスク欄の未確定の文字も、移れたとき以外は変えない。
    static func result(of attempt: Attempt) -> Result {
        let stay = Result(
            monthKey: attempt.currentMonthKey,
            logDraft: attempt.logDraft,
            isEditingLog: attempt.isEditingLog,
            taskDraft: attempt.taskDraft,
            showsDeleteConfirmation: false,
            blockedBySaveOrLoad: false
        )
        guard let destination = attempt.destinationMonthKey else {
            return stay
        }
        if destination == attempt.currentMonthKey {
            return stay
        }
        let before = phaseBeforeSideEffects(
            isEditingLog: attempt.isEditingLog,
            needsDeleteConfirmation: attempt.needsDeleteConfirmation,
            taskDraft: attempt.taskDraft
        )
        switch before {
        case .confirmDelete:
            var blocked = stay
            blocked.showsDeleteConfirmation = true
            return blocked
        case .keepTaskDraft:
            return stay
        case .prepareDestination:
            return commit(
                attempt,
                destination: destination,
                stay: stay,
                clearLogDraft: false
            )
        case .saveLog:
            let after = phaseAfterLogSave(
                logSaveSucceeded: attempt.logSaveSucceeded,
                loadFailed: attempt.loadFailed,
                taskDraft: attempt.taskDraft
            )
            switch after {
            case .stayAfterLogFailure:
                var blocked = stay
                blocked.blockedBySaveOrLoad = true
                blocked.isEditingLog = true
                blocked.logDraft = attempt.logDraft
                return blocked
            case .keepTaskDraft:
                var kept = stay
                kept.isEditingLog = false
                kept.logDraft = ""
                return kept
            case .prepareDestination:
                return commit(
                    attempt,
                    destination: destination,
                    stay: stay,
                    clearLogDraft: true
                )
            case .confirmDelete, .saveLog:
                return stay
            }
        case .stayAfterLogFailure:
            var blocked = stay
            blocked.blockedBySaveOrLoad = true
            return blocked
        }
    }

    /// ページの保存と、移る先の読み込みが成功したときだけ月を変える。
    ///
    /// 1行の保存がすでに成功しているときは、移動に失敗しても1行の下書きは閉じる。
    /// 文章は保存済みで、画面の行に残る。タスク欄は、移れたときだけ空にする。
    private static func commit(
        _ attempt: Attempt,
        destination: String,
        stay: Result,
        clearLogDraft: Bool
    ) -> Result {
        let ready = shouldCommitMove(
            pageSaveSucceeded: attempt.pageSaveSucceeded,
            destinationLoadSucceeded: attempt.destinationLoadSucceeded
        )
        if ready == false {
            var blocked = stay
            blocked.blockedBySaveOrLoad = true
            if clearLogDraft {
                blocked.isEditingLog = false
                blocked.logDraft = ""
            }
            return blocked
        }
        var moved = stay
        moved.monthKey = destination
        moved.isEditingLog = false
        moved.logDraft = ""
        moved.taskDraft = ""
        moved.showsDeleteConfirmation = false
        moved.blockedBySaveOrLoad = false
        return moved
    }
}
