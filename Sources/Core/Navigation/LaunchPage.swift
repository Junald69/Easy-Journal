import Foundation

/// 起動時の最初のページを決めて、Router（道案内係。今どのページを開いているかを覚える係）を1つ作る。
///
/// 画面は開かない。`-openPage` の文字列と「いま」から、最初のページを決めるだけ。
/// `openPage` が nil、または `PageRef` として読めないときは、`Router` の初期値のまま
/// （渡した「いま」の月の記録）。クラッシュしない。
enum LaunchPage {
    /// `openPage` は起動引数 `-openPage` の次の文字列。無ければ nil。
    /// `now` は「いま」。`calendar` はそのとき使う暦。
    static func makeRouter(openPage: String?, now: Date, calendar: Calendar) -> Router {
        let router = Router(now: now, calendar: calendar)
        if let text = openPage, let page = PageRef(openPage: text) {
            router.open(page)
        }
        return router
    }
}
