import Foundation

/// 今開いているページを表す値。画面そのものではない。
///
/// 文字列の形（起動引数 `-openPage` の次に書く想定）:
/// - 月の記録: `monthly:2026-10`
/// - 月の習慣表: `tracker:2026-10`
/// - その日のページ: `daily:2026-10-27`
///
/// 日付と月が実在するかは `DateKey` に任せる。不正な文字列は nil。クラッシュしない。
enum PageRef: Hashable {
    /// 月の記録（Monthly Log）。`monthKey` は `yyyy-MM`。
    case monthlyLog(monthKey: String)
    /// 月の習慣表（Monthly Tracker）。`monthKey` は `yyyy-MM`。
    case monthlyTracker(monthKey: String)
    /// その日のページ（Daily）。`dateKey` は `yyyy-MM-dd`。
    case daily(dateKey: String)

    /// `-openPage` に渡す文字列から作る。
    /// 形が違う、日付が無い、空白がある、大文字が混ざるときは nil。
    init?(openPage text: String) {
        guard !text.isEmpty, text.allSatisfy({ !$0.isWhitespace }) else { return nil }
        guard let colonIndex = text.firstIndex(of: ":") else { return nil }
        let kind = String(text[..<colonIndex])
        let key = String(text[text.index(after: colonIndex)...])
        guard !key.isEmpty, key.firstIndex(of: ":") == nil else { return nil }
        switch kind {
        case "monthly":
            guard DateKey.isValidMonthKey(key) else { return nil }
            self = .monthlyLog(monthKey: key)
        case "tracker":
            guard DateKey.isValidMonthKey(key) else { return nil }
            self = .monthlyTracker(monthKey: key)
        case "daily":
            guard DateKey.isValidDayKey(key) else { return nil }
            self = .daily(dateKey: key)
        default:
            return nil
        }
    }

    /// `-openPage` に渡す文字列。上の初期化で読むと、同じページに戻る。
    var openPageText: String {
        switch self {
        case .monthlyLog(let monthText):
            return "monthly:\(monthText)"
        case .monthlyTracker(let monthText):
            return "tracker:\(monthText)"
        case .daily(let dayText):
            return "daily:\(dayText)"
        }
    }
}
