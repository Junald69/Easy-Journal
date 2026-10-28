import Foundation
import Observation

/// 今どのページを開いているかを覚える係。
///
/// 画面は持たない。見開き（Spread）など、将来の iPad 用の項目は持たない。
/// 最初のページは、渡した「いま」の月の記録（Monthly Log）。
@Observable
final class Router {
    /// 今開いているページ。
    var current: PageRef

    /// ページ一覧を出しているか。最初は出していない。
    var isIndexPresented = false

    /// `now` と `calendar` は、テストで固定できるように渡す。
    /// 暦を省略したときは、`DateKey` と同じく端末のタイムゾーンでグレゴリオ暦を作る。
    init(now: Date = Date(), calendar: Calendar = DateKey.makeCalendar()) {
        let monthText = DateKey.monthKey(from: now, calendar: calendar)
        current = .monthlyLog(monthKey: monthText)
    }

    /// 指定したページを開く。
    func open(_ ref: PageRef) {
        current = ref
    }

    /// URL を読んで開く。読めたときだけ true を返し、ページを変える。
    /// 読めないときは false を返し、`current` はそのまま。
    ///
    /// `now` と `calendar` は `today` のときに使う。省略すると、呼んだ瞬間の時計と端末の暦。
    @discardableResult
    func open(url: URL, now: Date = Date(), calendar: Calendar = DateKey.makeCalendar()) -> Bool {
        guard let parsed = DeepLink.pageRef(from: url, now: now, calendar: calendar) else {
            return false
        }
        current = parsed
        return true
    }
}
