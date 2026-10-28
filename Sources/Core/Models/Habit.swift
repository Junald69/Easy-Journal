import Foundation
import SwiftData

/// 習慣の定義。月ごとに持つ。
///
/// チェックした記録（`HabitEntry`）とは関係でつながない。`HabitEntry` は habitID（UUID）だけ持つ。
/// 日ページを消しても、習慣の定義は消さない（月ページを消したときだけ、こちら側のルールで消える）。
/// 前月からの引き継ぎは UUID だけ。関係にはしない。
/// ユニーク制約（同じ値を禁止する印）は付けない。
@Model
final class Habit {
    /// 習慣を見分ける ID。
    var id: UUID = UUID()
    /// 習慣の名前。
    var name: String = ""
    /// 列の見出し用の短い文字（1〜2文字、またはアイコンの名前）。
    var shortLabel: String = ""
    /// 色（例：`#00AA00`）。nil は標準の色。
    var colorHex: String? = nil
    /// 並び順。小さいほど左（または上）。
    var sortOrder: Int = 0
    /// 前月から引き継いだ元の習慣 ID。関係にはしない。
    var carriedFromHabitID: UUID? = nil

    /// 属している月ページ。
    @Relationship
    var monthly: MonthlyPage? = nil

    init(
        id: UUID = UUID(),
        name: String = "",
        shortLabel: String = "",
        colorHex: String? = nil,
        sortOrder: Int = 0,
        carriedFromHabitID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.shortLabel = shortLabel
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.carriedFromHabitID = carriedFromHabitID
    }
}

/// 習慣を、ある日にチェックした記録。
///
/// DailyPage とは独立。日付は dateKey でつなぐだけ。
/// 習慣そのものとも関係にしない。`habitID`（UUID）だけ持つ。
/// 同じ日でも、習慣が違えば複数あってよい。同じ習慣の重複を防ぐ処理は T-106。
/// ユニーク制約（同じ値を禁止する印）は付けない。
/// 日ページを消しても、この記録は残す。
@Model
final class HabitEntry {
    /// チェック1件を見分ける ID。
    var id: UUID = UUID()
    /// どの習慣か。関係にはしない。
    var habitID: UUID = UUID()
    /// 日付（例：`2026-10-27`）。
    var dateKey: String = ""
    /// チェックしたか。記録があるときは、基本 true。
    var isDone: Bool = true
    /// 最後に更新した時刻。
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        habitID: UUID = UUID(),
        dateKey: String = "",
        isDone: Bool = true,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.habitID = habitID
        self.dateKey = dateKey
        self.isDone = isDone
        self.updatedAt = updatedAt
    }
}
