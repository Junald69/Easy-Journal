import Foundation

/// 月を移る前の判定。保存しない。画面を持たない。
///
/// 画面の ◀▶ も、外からの「この月を開いて」も、ここが返す段階だけを順に実行する。
/// 移動先の月キーは、呼び出し側が渡す。同じ判定を画面側に書き直さない。
/// 1行を片付ける条件は、月のタスクを触るときと同じ（`MonthlyTaskActionRule`）。
/// 保存に失敗したとき、そのあとの読み込みに失敗したときは、月を移さない。
/// 文章を空にして消す下書きは、確認の前に消さない。
/// タスクの追加欄に、空白以外の未確定の文字があるときは、1行の保存や編集終了より前に止める。
/// 文字は捨てない。編集中の1行も閉じない。
enum MonthMoveRule {
    /// ボタンを押した直後、保存するより前の段階。
    ///
    /// 1行の保存失敗は、ここには入れない。保存したあとの `AfterLogSave` で見る。
    enum BeforeMove: Equatable {
        /// 空にした1行の確認を出す。月は移さない。下書きは残す。
        case confirmDelete
        /// タスク名の未確定の文字を残して、月は移さない。1行は保存しない。編集も閉じない。
        case keepTaskDraft
        /// 編集中の1行を、今までと同じ保存で確定してから続きを見る。
        case saveLog
        /// 移る先の月ページを用意して、読めたときだけ移る。
        case prepareDestination
    }

    /// 1行を保存したあと。タスク欄は、保存の前に見終わっている。
    enum AfterLogSave: Equatable {
        /// 1行の保存か、そのあとの読み込みに失敗した。下書きを残して月は移さない。
        case stayAfterLogFailure
        /// 移る先の月ページを用意して、読めたときだけ移る。
        case prepareDestination
    }

    /// 移動の準備が終わったあとに出す失敗。成功は `none`。前の失敗は残さない。
    enum MoveProblem: Equatable {
        case none
        case save
        case load
    }

    /// 編集欄からフォーカスが外れたとき。◀▶ のキーボード閉じと同じ入口になりうる。
    enum LogFocusLoss: Equatable {
        /// 空にして消す確認。保存しない。
        case confirmDelete
        /// タスク欄に未確定がある。保存しない。編集も閉じない。
        case keepForTaskDraft
        /// 今までどおり保存する。
        case save
    }

    /// 1回の移動で、画面がどうなるかの結果。テストが、画面の手順と突き合わせる。
    struct Attempt: Equatable {
        var currentMonthKey: String
        /// 計算できなかったときは nil。月は動かない。
        var destinationMonthKey: String?
        var isEditingLog: Bool
        var needsDeleteConfirmation: Bool
        var logDraft: String
        /// 1行を保存したあとの戻り値。編集していないとき、保存の前に止まったときは使わない。
        var logSaveSucceeded: Bool
        /// 1行の保存のあとの読み込みが失敗したか。編集していないとき、保存の前に止まったときは使わない。
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
        /// タスク欄が理由で止めた。止めたときだけ、案内の文を出す。
        var showsTaskDraftBlockMessage: Bool
        /// 保存か読み込みに失敗して、月を止めた。
        var blockedBySaveOrLoad: Bool
        /// この移動で出す失敗。成功、または保存の前に止めたときは `none`。
        var moveProblem: MoveProblem
    }

    /// タスク欄が理由で月を止めたときに出す文。
    static let taskDraftBlockMessage = "タスクを追加するか、入力を消してから月を移動してください"

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

    /// 1行の保存先は、編集を始めた日付のまま。開いている月からは作り直さない。
    static func logSaveDateKey(editingDateKey: String) -> String? {
        guard DateKey.isValidDayKey(editingDateKey) else {
            return nil
        }
        return editingDateKey
    }

    /// 保存するより前。削除の確認を先に、その次にタスク欄を見る。1行の保存は最後。
    static func phaseBeforeSideEffects(
        isEditingLog: Bool,
        needsDeleteConfirmation: Bool,
        taskDraft: String
    ) -> BeforeMove {
        if isEditingLog && needsDeleteConfirmation {
            return .confirmDelete
        }
        if hasUncommittedTaskDraft(taskDraft) {
            return .keepTaskDraft
        }
        if isEditingLog {
            return .saveLog
        }
        return .prepareDestination
    }

    /// 編集欄からフォーカスが外れたとき。削除の確認、タスク欄、保存の順。
    ///
    /// ◀▶ の最初のタップがキーボードを閉じるだけのとき、この判定が先に走る。
    /// タスク欄に未確定があるときは、ここでは保存も閉じもしない。
    static func logFocusLoss(needsDeleteConfirmation: Bool, taskDraft: String) -> LogFocusLoss {
        if needsDeleteConfirmation {
            return .confirmDelete
        }
        if hasUncommittedTaskDraft(taskDraft) {
            return .keepForTaskDraft
        }
        return .save
    }

    /// 1行を保存したあと。続けてよいかは `MonthlyTaskActionRule` に聞く。
    ///
    /// 保存に失敗したときも、保存のあとの読み込みに失敗したときも、月は移さない。
    /// どちらも、1行の下書きは捨てない。タスク欄は、保存の前に見終わっている。
    static func phaseAfterLogSave(logSaveSucceeded: Bool, loadFailed: Bool) -> AfterLogSave {
        let mayContinue = MonthlyTaskActionRule.mayProceedAfterLogSave(
            logSaveSucceeded: logSaveSucceeded,
            loadFailed: loadFailed
        )
        if mayContinue == false {
            return .stayAfterLogFailure
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

    /// この移動で出す失敗。成功なら `none` で、前の失敗を消す。
    ///
    /// 保存の失敗と読み込みの失敗は、同時には出さない。新しい方だけを残す。
    static func problemAfterPrepare(pageSaveSucceeded: Bool, destinationLoadSucceeded: Bool) -> MoveProblem {
        if pageSaveSucceeded == false {
            return .save
        }
        if destinationLoadSucceeded == false {
            return .load
        }
        return .none
    }

    /// この段階で、1行の下書きを画面から消してよいか。
    ///
    /// 保存も、そのあとの読み込みも成功したときだけ true。失敗したあとは false。
    static func mayDiscardLogDraft(_ after: AfterLogSave) -> Bool {
        switch after {
        case .prepareDestination:
            return true
        case .stayAfterLogFailure:
            return false
        }
    }

    /// 画面の手順と同じ順で、移動の結果を返す。
    ///
    /// 移動先は、◀▶ の隣の月でも、外から頼まれた月でも同じ。
    ///
    /// 失敗したときは、開いている月と1行の下書きを変えない。
    /// タスク欄の未確定で止めたときは、1行は保存しない。編集も閉じない。
    /// 移る先の保存か読み込みに失敗したときは、Router の月も変えない。
    static func result(of attempt: Attempt) -> Result {
        let stay = Result(
            monthKey: attempt.currentMonthKey,
            logDraft: attempt.logDraft,
            isEditingLog: attempt.isEditingLog,
            taskDraft: attempt.taskDraft,
            showsDeleteConfirmation: false,
            showsTaskDraftBlockMessage: false,
            blockedBySaveOrLoad: false,
            moveProblem: .none
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
            var blocked = stay
            blocked.showsTaskDraftBlockMessage = true
            return blocked
        case .prepareDestination:
            return commit(attempt, destination: destination, stay: stay, clearLogDraft: false)
        case .saveLog:
            let after = phaseAfterLogSave(
                logSaveSucceeded: attempt.logSaveSucceeded,
                loadFailed: attempt.loadFailed
            )
            switch after {
            case .stayAfterLogFailure:
                var blocked = stay
                blocked.blockedBySaveOrLoad = true
                blocked.isEditingLog = true
                blocked.logDraft = attempt.logDraft
                return blocked
            case .prepareDestination:
                return commit(attempt, destination: destination, stay: stay, clearLogDraft: true)
            }
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
        let problem = problemAfterPrepare(
            pageSaveSucceeded: attempt.pageSaveSucceeded,
            destinationLoadSucceeded: attempt.destinationLoadSucceeded
        )
        if ready == false {
            var blocked = stay
            blocked.blockedBySaveOrLoad = true
            blocked.moveProblem = problem
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
        moved.showsTaskDraftBlockMessage = false
        moved.blockedBySaveOrLoad = false
        moved.moveProblem = .none
        return moved
    }
}
