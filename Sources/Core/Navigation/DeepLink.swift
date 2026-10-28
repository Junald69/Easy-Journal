import Foundation

/// `easyjournal://` の URL を、開くページ（`PageRef`）に変える。
///
/// 画面は開かない。文字を読むだけ。URL スキーム（この住所をアプリが受け取ると登録すること）は、ここではしない。
/// 不正な URL は nil。クラッシュしない。
///
/// 受け付ける住所:
/// - `easyjournal://daily/today` … 渡した「いま」の日
/// - `easyjournal://daily/2026-10-27` … 指定した日
/// - `easyjournal://monthly/2026-10` … 指定した月の記録
/// - `easyjournal://monthly/today` … 渡した「いま」の月の記録（設計資料の例には無い）
/// - `easyjournal://tracker/2026-10` … 指定した月の習慣表
///
/// `today` は、引数の「いま」を、引数の暦のタイムゾーンで見た日または月。`DateKey` に任せる。保存しない。
/// `tracker/today` は受けない。
///
/// 大文字と小文字はそろえない。`easyjournal`、`daily`、`monthly`、`tracker`、`today` は小文字と完全に一致したときだけ受ける。
/// `lowercased()` は呼ばない。
enum DeepLink {
    /// URL からページを作る。
    ///
    /// `absoluteString`（URL を文字列に戻したもの）を、下の文字列の規則で読む。
    /// URL 型がこの文字列を書き換えるかは未確認（要確認）。
    static func pageRef(from url: URL, now: Date, calendar: Calendar) -> PageRef? {
        pageRef(from: url.absoluteString, now: now, calendar: calendar)
    }

    /// 文字列からページを作る。前後の空白、大文字、形の違いは nil。
    static func pageRef(from text: String, now: Date, calendar: Calendar) -> PageRef? {
        guard let parts = linkParts(text) else { return nil }
        return ref(host: parts.host, segment: parts.segment, now: now, calendar: calendar)
    }

    /// `easyjournal://host/segment` だけを取り出す。クエリ（`?`）や断片（`#`）は拒否する。
    private static func linkParts(_ text: String) -> (host: String, segment: String)? {
        guard !text.isEmpty, text.allSatisfy({ !$0.isWhitespace }) else { return nil }
        let marker = "://"
        guard let markerRange = text.range(of: marker) else { return nil }
        let scheme = String(text[..<markerRange.lowerBound])
        guard scheme == "easyjournal" else { return nil }
        let afterMarker = text[markerRange.upperBound...]
        guard afterMarker.range(of: marker) == nil else { return nil }
        guard afterMarker.firstIndex(of: "?") == nil, afterMarker.firstIndex(of: "#") == nil else {
            return nil
        }
        let pieces = afterMarker.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2 else { return nil }
        let host = String(pieces[0])
        let segment = String(pieces[1])
        guard !host.isEmpty, !segment.isEmpty else { return nil }
        return (host, segment)
    }

    private static func ref(host: String, segment: String, now: Date, calendar: Calendar) -> PageRef? {
        switch host {
        case "daily":
            if segment == "today" {
                let todayText = DateKey.todayKey(now: now, calendar: calendar)
                return .daily(dateKey: todayText)
            }
            guard DateKey.isValidDayKey(segment) else { return nil }
            return .daily(dateKey: segment)
        case "monthly":
            if segment == "today" {
                let monthText = DateKey.monthKey(from: now, calendar: calendar)
                return .monthlyLog(monthKey: monthText)
            }
            guard DateKey.isValidMonthKey(segment) else { return nil }
            return .monthlyLog(monthKey: segment)
        case "tracker":
            // `tracker/today` は受けない。月キーだけ。
            guard DateKey.isValidMonthKey(segment) else { return nil }
            return .monthlyTracker(monthKey: segment)
        default:
            return nil
        }
    }
}
