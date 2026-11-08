import Foundation

/// 編集を始めたときの元の文字。読み直しで表示が空になっても残す。
///
/// 保存しない。画面を持たない。
/// 確認が要るかは、`MonthlyLogEditRule` に聞く。
struct MonthlyLogEditSession: Equatable {
    /// 編集中の行の、いま残しておく文章。
    ///
    /// 編集を始めたときの文字。保存に成功したら、保存した下書きに置き換える。
    /// 編集していないときは nil。
    private var original: String?

    /// 編集していない状態で作る。
    init() {
        original = nil
    }

    /// 編集を始める。その行の元の文字を覚える。
    mutating func begin(original: String?) {
        self.original = original
    }

    /// 編集を続けたまま、保存が成功したとき。
    ///
    /// 記録は、もう下書きの文字になっている。次の確認とキャンセルは、この文字を元にする。
    mutating func didSave(text: String) {
        original = text
    }

    /// 編集を閉じたとき。覚えていた文字を忘れる。
    mutating func clear() {
        original = nil
    }

    /// 今の下書きを確定すると、保存してある文章が消えるとき true。
    ///
    /// 表示の読み直しが失敗して空でも、覚えていた元の文字で判定する。
    func needsDeleteConfirmation(draft: String) -> Bool {
        MonthlyLogEditRule.needsDeleteConfirmation(original: original, draft: draft)
    }

    /// キャンセルで戻す文字。元が無いときは空。
    var restoreText: String {
        original ?? ""
    }
}
