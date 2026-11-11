import Foundation
import Observation

/// 月の画面へ「この月を開いて」と頼む印。表示している月は、これだけでは変えない。
///
/// 同じ月をもう一度頼んでも、画面が別の依頼だと分かるように `token` を増やす。
struct MonthNavigationRequest: Equatable {
    var monthKey: String
    var token: Int
}

/// 今どのページを開いているかを覚える係。
///
/// 画面は持たない。見開き（Spread）など、将来の iPad 用の項目は持たない。
/// 最初のページは、渡した「いま」の月の記録（Monthly Log）。
/// 表示している月は、ここだけが持つ。
/// 起動時と `-openPage` は `open` で最初のページを決める。月の画面が出たあとは、
/// 別の月の記録を `open` しても表示は変えない。`requestMonth` の依頼になる。
/// 日のページや習慣表も、月の画面が出ているあいだはすぐ開かない。`pageLeaveRequest` になる。
/// 月の画面が、◀▶ と同じ確認と保存のあとにだけページを変える。
/// 月なら `commitDisplayedMonth`、それ以外なら `resolveGuardedOpen` の通過だけ。
/// そのときだけ、表示しているページが変わる。
@Observable
final class Router {
    /// 今開いているページ。
    private(set) var current: PageRef

    /// ページ一覧を出しているか。最初は出していない。
    var isIndexPresented = false

    /// 月の画面がまだ片付けていない依頼。無いときは nil。表示中の月は変えない。
    private(set) var monthRequest: MonthNavigationRequest?

    /// 月の画面から、日のページや習慣表へ出る依頼。無いときは nil。表示中のページは変えない。
    private(set) var pageLeaveRequest: PageLeaveRequest?

    /// 月の画面が出ているあいだ true。そのあいだ、別のページへの `open` は依頼にする。
    private var guardsMonthlyNavigation = false

    /// 依頼を区別する番号。成功でも失敗でも、画面が同じ依頼を繰り返さないように増やす。
    private var monthRequestToken = 0

    /// 月の画面を出る依頼を区別する番号。
    private var pageLeaveToken = 0

    /// 使い切った月移動の承諾。同じ値では、もう月を変えない。
    private var consumedMonthMoveNonces: Set<UUID> = []

    /// 使い切った、月の画面を出る承諾。同じ値では、もうページを変えない。
    private var consumedPageLeaveNonces: Set<UUID> = []

    /// `now` と `calendar` は、テストで固定できるように渡す。
    /// 暦を省略したときは、`DateKey` と同じく端末のタイムゾーンでグレゴリオ暦を作る。
    init(now: Date = Date(), calendar: Calendar = DateKey.makeCalendar()) {
        let monthText = DateKey.monthKey(from: now, calendar: calendar)
        current = .monthlyLog(monthKey: monthText)
    }

    /// 指定したページを開く。
    ///
    /// 起動時と `-openPage` は、月の画面が出る前に呼ぶ。そのときは、渡したページを開く。
    /// 月の画面が出ているあいだ、別の月の記録は開かず、`requestMonth` に回す。
    /// 日のページや習慣表も開かず、`pageLeaveRequest` に回す。
    /// どちらも、確認と保存が通るまで `current` は変えない。
    func open(_ ref: PageRef) {
        if let monthKey = monthKeyToRequest(insteadOf: ref) {
            pageLeaveRequest = nil
            requestMonth(monthKey)
            return
        }
        if shouldRequestPageLeave(insteadOf: ref) {
            monthRequest = nil
            pageLeaveToken += 1
            pageLeaveRequest = PageLeaveRequest(destination: ref, token: pageLeaveToken)
            return
        }
        current = ref
        monthRequest = nil
        pageLeaveRequest = nil
    }

    /// URL を読んで開く。読めたときだけ true を返す。
    /// 読めないときは false を返し、`current` も依頼も変えない。
    ///
    /// 月の画面が出ているあいだ、別の月の記録として読めた URL は依頼にする。
    /// 日のページや習慣表として読めた URL も、出る依頼にする。
    /// そのときも true。表示しているページは、画面が承諾するまで変えない。
    /// `now` と `calendar` は `today` のときに使う。省略すると、呼んだ瞬間の時計と端末の暦。
    @discardableResult
    func open(url: URL, now: Date = Date(), calendar: Calendar = DateKey.makeCalendar()) -> Bool {
        guard let parsed = DeepLink.pageRef(from: url, now: now, calendar: calendar) else {
            return false
        }
        open(parsed)
        return true
    }

    /// 月の画面が出た。これ以降、別の月への `open` は依頼にする。
    func beginGuardingMonthlyNavigation() {
        guardsMonthlyNavigation = true
    }

    /// 月の画面が閉じた。依頼も捨てる。閉じた画面は、もう片付けない。
    ///
    /// 遅れて届いた移動も、ここを通ったあとはページを変えない。
    func endGuardingMonthlyNavigation() {
        guardsMonthlyNavigation = false
        monthRequest = nil
        pageLeaveRequest = nil
    }

    /// 画面の外から、この月を開いてほしいと頼む。表示している月は変えない。
    ///
    /// 月キーとして読めないときは、何もしない。今の依頼も捨てない。
    /// 月の画面が、◀▶ と同じ順で確認し、成功したときだけ `commitDisplayedMonth` を呼ぶ。
    func requestMonth(_ monthKey: String) {
        guard DateKey.isValidMonthKey(monthKey) else {
            return
        }
        pageLeaveRequest = nil
        monthRequestToken += 1
        monthRequest = MonthNavigationRequest(monthKey: monthKey, token: monthRequestToken)
    }

    /// 画面が依頼を見た。成功でも失敗でも、同じ依頼ではもう一度動かさない。
    func clearMonthRequest() {
        monthRequest = nil
    }

    /// 月の画面が、確認と保存と読み込みのあとにだけ呼ぶ。
    ///
    /// `authorization` は、その移動が成功したときだけ作れる。移る先の月と、依頼があるときはその番号に結び付く。
    /// 1回使うと、同じ値ではもう変えない。別の月でも変えない。
    /// 月の画面が出ていないときも変えない。閉じたあとに遅れて届いても、表示月は残る。
    /// 無い値では表示月は変えない。起動時と `-openPage` は、ここを通さず `open` を使う。
    /// 月キーとして読めないときも、表示月は変えない。承諾は、そのときは使い切らない。
    @discardableResult
    func commitDisplayedMonth(
        _ monthKey: String,
        requestToken: Int? = nil,
        authorization: MonthMoveAuthorization
    ) -> Bool {
        guard guardsMonthlyNavigation else {
            return false
        }
        guard DateKey.isValidMonthKey(monthKey) else {
            return false
        }
        guard authorization.claim(
            monthKey: monthKey,
            requestToken: requestToken,
            ledger: &consumedMonthMoveNonces
        ) else {
            return false
        }
        let wasGuarding = guardsMonthlyNavigation
        guardsMonthlyNavigation = false
        defer {
            guardsMonthlyNavigation = wasGuarding
        }
        open(.monthlyLog(monthKey: monthKey))
        return current == .monthlyLog(monthKey: monthKey)
    }

    /// 月の画面が、日のページや習慣表を開く前の確認を終えたときに呼ぶ。
    ///
    /// `.blocked` と `.failed` では、ページを変えない。依頼だけ片付ける。
    /// `.passed` でも、承諾がその行き先と依頼番号に一致し、まだ使っていないときだけ変える。
    /// 月の画面が出ていないときは、何も変えない。
    @discardableResult
    func resolveGuardedOpen(
        _ destination: PageRef,
        requestToken: Int,
        resolution: GuardedOpenResolution
    ) -> Bool {
        guard guardsMonthlyNavigation else {
            return false
        }
        guard let request = pageLeaveRequest else {
            return false
        }
        guard request.token == requestToken, request.destination == destination else {
            return false
        }
        switch resolution {
        case .blocked, .failed:
            pageLeaveRequest = nil
            return false
        case .passed(let authorization):
            guard authorization.claim(
                destination: destination,
                requestToken: requestToken,
                ledger: &consumedPageLeaveNonces
            ) else {
                return false
            }
            guardsMonthlyNavigation = false
            open(destination)
            return current == destination
        }
    }

    /// 月の画面が出ていて、別の月の記録を開こうとしているとき、その月キー。それ以外は nil。
    private func monthKeyToRequest(insteadOf ref: PageRef) -> String? {
        guard guardsMonthlyNavigation else {
            return nil
        }
        guard case .monthlyLog(let monthKey) = ref else {
            return nil
        }
        guard case .monthlyLog(let openMonth) = current else {
            return nil
        }
        guard monthKey != openMonth else {
            return nil
        }
        guard DateKey.isValidMonthKey(monthKey) else {
            return nil
        }
        return monthKey
    }

    /// 月の画面が出ていて、月の記録以外を開こうとしているとき true。
    private func shouldRequestPageLeave(insteadOf ref: PageRef) -> Bool {
        guard guardsMonthlyNavigation else {
            return false
        }
        switch ref {
        case .monthlyLog:
            return false
        case .daily, .monthlyTracker:
            return true
        }
    }
}

/// 月の画面から、別の種類のページへ出る依頼。表示しているページは、これだけでは変えない。
struct PageLeaveRequest: Equatable {
    var destination: PageRef
    var token: Int
}

/// 月の画面を出る確認の結果。通過したときだけ、ページを変えてよい。
enum GuardedOpenResolution: Equatable {
    /// 削除の確認か、タスク欄の未確定で止めた。ページは変えない。
    case blocked
    /// 一言日記の保存に失敗した。ページは変えない。下書きは残す。
    case failed
    /// 確認と保存が通った。承諾が一致するときだけページを変える。
    case passed(PageLeaveAuthorization)
}
