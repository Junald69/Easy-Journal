import SwiftUI

/// いま開いているページを出す。月の記録だけ、Monthly Log の画面。それ以外は仮の画面。
///
/// 開いている月は Router だけが持つ。◀▶ も、外からの依頼も、月の画面を出る開き方も、確認と保存ができたときだけ Router を変える。
struct RootPageView: View {
    /// アプリが持つ Router。確認が通ったときだけ、開いているページを変える。
    let router: Router
    /// 今日の日付キー。月の画面の帯とスクロールに渡す。
    let todayKey: String
    /// Debug かつメモリ上の保存先のときだけ、次の月移動を1回失敗させる。
    var monthMoveFailure: MonthMoveFailureInjection? = nil
    /// Debug かつメモリ上の保存先のときだけ、◀▶ と同じ確認を通してこの月を開くボタンを出す。
    var debugJumpMonth: String? = nil
    /// Debug かつメモリ上の保存先のときだけ、確認を通してこの URL を開くボタンを出す。
    var debugOpenURL: URL? = nil

    var body: some View {
        page
            .overlay(alignment: .topLeading) {
                if debugJumpMonth != nil || debugOpenURL != nil {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                        if let debugJumpMonth {
                            Button("月を開く") {
                                router.requestMonth(debugJumpMonth)
                            }
                            .accessibilityIdentifier("debugJumpMonth")
                        }
                        if let debugOpenURL {
                            Button("ページを開く") {
                                _ = router.open(url: debugOpenURL)
                            }
                            .accessibilityIdentifier("debugOpenURL")
                        }
                    }
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
                openMonth: { destination, requestToken, authorization in
                    router.commitDisplayedMonth(
                        destination,
                        requestToken: requestToken,
                        authorization: authorization
                    )
                },
                monthRequest: router.monthRequest,
                acknowledgeMonthRequest: {
                    router.clearMonthRequest()
                },
                pageLeaveRequest: router.pageLeaveRequest,
                resolvePageLeave: { destination, requestToken, resolution in
                    router.resolveGuardedOpen(
                        destination,
                        requestToken: requestToken,
                        resolution: resolution
                    )
                },
                monthMoveFailure: monthMoveFailure
            )
            .id("monthlyLogPage")
            .onAppear {
                router.beginGuardingMonthlyNavigation()
            }
            .onDisappear {
                router.endGuardingMonthlyNavigation()
            }
        default:
            PlaceholderPageView(router: router)
        }
    }
}
