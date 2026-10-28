import Foundation
import SwiftData

/// 1日分の中身。目次カードは `Page`。
///
/// 同じ dateKey で2つ作らない。作るときは findOrCreate を通す（T-105）。
/// dateKey は、親の Page と同時に同じ値を入れる（T-105で保証）。
/// ユニーク制約（同じ値を禁止する印）は付けない。
/// 気分・睡眠・習慣のチェック・月の1行は、このクラスと関係でつながない。
@Model
final class DailyPage {
    /// 日ページを見分ける ID。
    var id: UUID = UUID()
    /// 日付（例：`2026-10-27`）。
    var dateKey: String = ""
    /// メモ。MVP では文章だけ。
    var memo: String = ""
    /// タスク一覧をたたんでいるか。
    var isTaskListCollapsed: Bool = false
    /// 紙の模様の文字列。`grid` / `lined` / `plain`。知らない文字のときは `grid` に戻す。
    var paperStyleRaw: String = PaperStyle.grid.rawValue
    /// 地の色の文字列。`white` / `offWhite` / `black`。知らない文字のときは `offWhite` に戻す。
    var backgroundRaw: String = PaperBackground.offWhite.rawValue
    /// 文字色（例：`#112233`）。nil は標準の色。
    var textColorHex: String? = nil

    /// 目次カード。日ページを消しても、目次カードは消さない。
    @Relationship
    var page: Page? = nil

    /// その日のタスク。日ページを消すと、これらのタスクも消える。
    /// タスクは日か月のどちらか一方に属する。もう一方は nil。
    @Relationship(deleteRule: .cascade, inverse: \JournalTask.daily)
    var tasks: [JournalTask]? = []

    /// 保存されない紙の模様。
    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .grid }
        set { paperStyleRaw = newValue.rawValue }
    }

    /// 保存されない地の色。
    var background: PaperBackground {
        get { PaperBackground(rawValue: backgroundRaw) ?? .offWhite }
        set { backgroundRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        dateKey: String = "",
        memo: String = "",
        isTaskListCollapsed: Bool = false,
        paperStyleRaw: String = PaperStyle.grid.rawValue,
        backgroundRaw: String = PaperBackground.offWhite.rawValue,
        textColorHex: String? = nil
    ) {
        self.id = id
        self.dateKey = dateKey
        self.memo = memo
        self.isTaskListCollapsed = isTaskListCollapsed
        self.paperStyleRaw = paperStyleRaw
        self.backgroundRaw = backgroundRaw
        self.textColorHex = textColorHex
    }
}
