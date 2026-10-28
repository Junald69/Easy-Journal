import Foundation
import SwiftData

/// 全ページ共通の「目次カード」。中身は `DailyPage` か `MonthlyPage`。
///
/// 同じ dateKey で2つ作らない。作るときは findOrCreate を通す（T-105）。
/// 月のページは、同じ monthKey で2つ作らない。作るときも findOrCreate を通す（T-105）。
/// dateKey と monthKey は、中身の DailyPage / MonthlyPage と同時に同じ値を入れる（T-105で保証）。
/// このチケットではユニーク制約（同じ値を禁止する印）は付けない。
///
/// 日を消す操作は、DailyPage ではなく、この Page を消す。Page から日の中身は cascade（一緒に消える）なので、日ページとタスクも消える。
/// DailyPage だけを消すと、Page は空のカード（種類は daily、中身は nil）として残る。月も同じ。月を消すときも Page を消す。
@Model
final class Page {
    /// ページを見分ける ID。
    var id: UUID = UUID()
    /// 種類の文字列。`daily` または `monthly`。知らない文字のときは、計算プロパティが `daily` に戻す。
    var kindRaw: String = PageKind.daily.rawValue
    /// 日のページの日付（例：`2026-10-27`）。月のページでは空（nil）でよい。
    var dateKey: String? = nil
    /// 月（例：`2026-10`）。日のページにも、まとめ用に入れる。
    var monthKey: String = ""
    /// 誰が作ったかの文字列。`user` / `carryOver` / `system`。知らない文字のときは `user` に戻す。
    var createdByRaw: String = PageCreatedBy.user.rawValue
    /// 作った時刻。
    var createdAt: Date = Date.now
    /// 最後に更新した時刻。
    var updatedAt: Date = Date.now

    /// 属している手帳。ページを消しても、手帳は消さない（反対側は nullify。つながりだけ外す）。
    @Relationship
    var journal: Journal? = nil

    /// 月の中身。このページを消すと、中身も消える（cascade）。
    /// MonthlyPage だけを消すと、この Page は空のカードとして残る（反対側は nullify。つながりだけ外す）。
    /// 日のページでは空（nil）。
    @Relationship(deleteRule: .cascade, inverse: \MonthlyPage.page)
    var monthly: MonthlyPage? = nil

    /// 日の中身。このページを消すと、中身も消える（cascade）。
    /// DailyPage だけを消すと、この Page は空のカードとして残る（反対側は nullify。つながりだけ外す）。
    /// 月のページでは空（nil）。
    @Relationship(deleteRule: .cascade, inverse: \DailyPage.page)
    var daily: DailyPage? = nil

    /// 保存されない種類。`kindRaw` を enum として読む。
    var kind: PageKind {
        get { PageKind(rawValue: kindRaw) ?? .daily }
        set { kindRaw = newValue.rawValue }
    }

    /// 保存されない「誰が作ったか」。`createdByRaw` を enum として読む。
    var createdBy: PageCreatedBy {
        get { PageCreatedBy(rawValue: createdByRaw) ?? .user }
        set { createdByRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        kindRaw: String = PageKind.daily.rawValue,
        dateKey: String? = nil,
        monthKey: String = "",
        createdByRaw: String = PageCreatedBy.user.rawValue,
        createdAt: Date = Date.now,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.dateKey = dateKey
        self.monthKey = monthKey
        self.createdByRaw = createdByRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
