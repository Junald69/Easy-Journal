import Foundation

/// タスク欄で月を止めているあいだ、一言日記の編集を閉じないための印。
///
/// 日記を閉じたとき、タスクを追加したときは、両方を戻す。
/// 戻さないと、次の日記は焦点が外れても保存されない。
struct LogEditorHoldState: Equatable {
    /// このあいだ、焦点が外れても一言日記は閉じない。
    var holdLogEditor = false
    /// 名前を空にしたあと、一言日記へ焦点を戻す日付。無いときは nil。
    var restoreLogFocusDateKey: String? = nil

    /// 一言日記を編集したまま、タスク欄で月を止めた。
    mutating func blockWhileEditing() {
        holdLogEditor = true
    }

    /// 止めていたタスク名を消し、編集中の一言日記へ焦点を戻す。
    mutating func beginRestore(dateKey: String) {
        holdLogEditor = true
        restoreLogFocusDateKey = dateKey
    }

    /// 焦点を1回戻し終わった。止めが残っていなければ、保護も外す。
    mutating func finishRestore(stillBlocked: Bool) {
        restoreLogFocusDateKey = nil
        if stillBlocked == false {
            holdLogEditor = false
        }
    }

    /// 編集している日が無くなった。保護も戻し先も消す。
    mutating func editingClosed() {
        holdLogEditor = false
        restoreLogFocusDateKey = nil
    }

    /// タスク欄の止めが解けた。戻し先が無いときだけ、保護を外す。
    mutating func taskBlockEnded() {
        if restoreLogFocusDateKey == nil {
            holdLogEditor = false
        }
    }

    /// タスクを追加できた。日記はもう閉じているので、両方を戻す。
    mutating func taskAdded() {
        editingClosed()
    }
}
