import SwiftUI

/// いま開いているページを出す。月の記録だけ、Monthly Log の画面。それ以外は仮の画面。
struct RootPageView: View {
    /// アプリが持つ Router。この画面は、いまのページを読むだけ。
    let router: Router
    /// 今日の日付キー。月の画面の帯とスクロールに渡す。
    let todayKey: String

    var body: some View {
        switch router.current {
        case .monthlyLog(let monthKey):
            MonthlyLogPageView(monthKey: monthKey, todayKey: todayKey)
        default:
            PlaceholderPageView(router: router)
        }
    }
}
