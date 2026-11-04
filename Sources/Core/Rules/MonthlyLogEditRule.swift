import Foundation

/// 月の1行を編集するときのルール。保存しない。画面を持たない。
///
/// 文章がある行を、空白と改行だけにして確定する前に確認が要るかを返す。
/// 空白の範囲は、`setLogLine` が行を消すときと同じ（前後の空白と改行）。
enum MonthlyLogEditRule {
    /// 元の文章が残っていて、下書きが空のとき true。
    ///
    /// 比べる前に、前後の空白と改行を除く。元が nil、空、空白と改行だけのときは false。
    /// 消える文章がないので、確認は要らない。
    static func needsDeleteConfirmation(original: String?, draft: String) -> Bool {
        let kept = trimmed(original)
        if kept.isEmpty {
            return false
        }
        let next = trimmed(draft)
        return next.isEmpty
    }

    /// 前後の空白と改行を除く。nil は空文字にする。
    private static func trimmed(_ text: String?) -> String {
        guard let text else {
            return ""
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
