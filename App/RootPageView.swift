import SwiftUI

/// いま開いているページを出す。月の記録だけ、Monthly Log の画面。それ以外は仮の画面。
///
/// 開いている月は Router だけが持つ。◀▶ は、保存と読み込みができたときだけ Router を変える。
struct RootPageView: View {
    /// アプリが持つ Router。月の記録を移すときだけ、開いているページを変える。
    let router: Router
    /// 今日の日付キー。月の画面の帯とスクロールに渡す。
    let todayKey: String
    /// Debug かつメモリ上の保存先のときだけ、次の月移動を1回失敗させる。
    var monthMoveFailure: MonthMoveFailureInjection? = nil
    /// Debug かつメモリ上の保存先のときだけ、◀▶ を通さずにこの月を開くボタンを出す。
    var debugJumpMonth: String? = nil

    var body: some View {
        page
            .overlay(alignment: .topLeading) {
                if let debugJumpMonth {
                    Button("月を開く") {
                        router.open(.monthlyLog(monthKey: debugJumpMonth))
                    }
                    .accessibilityIdentifier("debugJumpMonth")
                    .padding(DesignTokens.Spacing.s)
                }
            }
    }

    @ViewBuilder
    private var page: some View {
        switch router.current {
        case .monthlyLog(let monthKey):
            MonthlyLogPageView(
                monthKey: monthKey,
                todayKey: todayKey,
                openMonth: { destination in
                    router.open(.monthlyLog(monthKey: destination))
                },
                monthMoveFailure: monthMoveFailure
            )
            .id("monthlyLogPage")
        default:
            PlaceholderPageView(router: router)
        }
    }
}
