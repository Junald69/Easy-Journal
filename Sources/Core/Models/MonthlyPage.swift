import Foundation
import SwiftData

/// 1か月分の中身。目次カードは `Page`。
///
/// 同じ monthKey で2つ作らない。作るときは findOrCreate を通す（T-105）。
/// monthKey は、親の Page と同時に同じ値を入れる（T-105で保証）。
/// 日の「1日1枚」と同じく、重複はコード側で防ぐ。ユニーク制約（同じ値を禁止する印）は付けない。
@Model
final class MonthlyPage {
    /// 月ページを見分ける ID。
    var id: UUID = UUID()
    /// 月（例：`2026-10`）。
    var monthKey: String = ""
    /// 月末の軽い振り返り。空でもよい。
    var reflection: String = ""

    /// 目次カード。月ページを消しても、目次カード側のルールはこちらでは消さない。
    @Relationship
    var page: Page? = nil

    /// その月の、1日1行。月ページを消すと、行も消える。
    /// 日のページ（DailyPage）とは関係でつながない。日付は dateKey の文字列だけ。
    @Relationship(deleteRule: .cascade, inverse: \MonthlyLogLine.monthly)
    var logLines: [MonthlyLogLine]? = []

    /// 月のタスク。月ページを消すと、これらのタスクも消える。
    /// タスクは日か月のどちらか一方に属する。もう一方は nil。
    @Relationship(deleteRule: .cascade, inverse: \JournalTask.monthly)
    var tasks: [JournalTask]? = []

    /// その月の習慣の定義。月ページを消すと、習慣の定義も消える。
    @Relationship(deleteRule: .cascade, inverse: \Habit.monthly)
    var habits: [Habit]? = []

    init(
        id: UUID = UUID(),
        monthKey: String = "",
        reflection: String = ""
    ) {
        self.id = id
        self.monthKey = monthKey
        self.reflection = reflection
    }
}

/// 月ページの、1日1行の文章。
///
/// 同じ dateKey で2つ作らない。作るときは findOrCreate を通す（T-105）。
/// DailyPage とは独立。日付は dateKey でつなぐだけ（関係にはしない）。
/// ユニーク制約（同じ値を禁止する印）は付けない。
@Model
final class MonthlyLogLine {
    /// 行を見分ける ID。
    var id: UUID = UUID()
    /// その行の日付（例：`2026-10-27`）。
    var dateKey: String = ""
    /// 1行の文章。
    var text: String = ""
    /// 最後に更新した時刻。
    var updatedAt: Date = Date.now

    /// 属している月ページ。行を消しても、月ページは消さない。
    @Relationship
    var monthly: MonthlyPage? = nil

    init(
        id: UUID = UUID(),
        dateKey: String = "",
        text: String = "",
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.dateKey = dateKey
        self.text = text
        self.updatedAt = updatedAt
    }
}
