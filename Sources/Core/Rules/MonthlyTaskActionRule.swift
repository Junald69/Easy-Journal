import Foundation

/// 1行を確定したあと、月のタスクの操作を続けてよいか。保存しない。画面を持たない。
///
/// `logSaveSucceeded` は、1行の保存（`saveDraft`）の戻り値そのもの。この関数はそれを変えない。
/// 保存に失敗したときは続けない。
/// 保存は成功しても、そのあとの読み込みに失敗したときは続けない。
/// タスクの名前欄に入っている文字は、ここでは触らない。
enum MonthlyTaskActionRule {
    /// 編集中の1行を保存したあと、タスクの追加・記号・削除依頼を続けてよいか。
    static func mayProceedAfterLogSave(logSaveSucceeded: Bool, loadFailed: Bool) -> Bool {
        if logSaveSucceeded == false {
            return false
        }
        if loadFailed {
            return false
        }
        return true
    }
}
