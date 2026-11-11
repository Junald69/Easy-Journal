import SwiftUI

/// いま開いているページを出す。月の記録だけ、Monthly Log の画面。それ以外は仮の画面。
///
/// ◀▶ で月が移れたときは、Router の月も同じにする。
struct RootPageView: View {
    /// アプリが持つ Router。月の記録を移すときだけ、開いているページを変える。
    let router: Router
    /// 今日の日付キー。月の画面の帯とスクロールに渡す。
    let todayKey: String

    var body: some View {
        switch router.current {
        case .monthlyLog(let monthKey):
            MonthlyLogPageView(
                monthKey: monthKey,
                todayKey: todayKey,
                openMonth: { destination in
                    router.open(.monthlyLog(monthKey: destination))
                }
            )
        default:
            PlaceholderPageView(router: router)
        }
    }
}
