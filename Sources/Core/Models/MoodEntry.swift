import Foundation
import SwiftData

/// その日の気分。DailyPage とは独立。日付は dateKey でつなぐだけ。
///
/// 同じ dateKey で2つ作らない。作るときは findOrCreate を通す（T-105）。
/// ユニーク制約（同じ値を禁止する印）は付けない。
/// 日ページを消しても、気分の記録は残す。
@Model
final class MoodEntry {
    /// 気分1件を見分ける ID。
    var id: UUID = UUID()
    /// 日付（例：`2026-10-27`）。
    var dateKey: String = ""
    /// 1〜5。標準は 3。
    var level: Int = 3
    /// メモ。いまは将来用。無くてよい。
    var note: String? = nil
    /// 最後に更新した時刻。
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        dateKey: String = "",
        level: Int = 3,
        note: String? = nil,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.dateKey = dateKey
        self.level = level
        self.note = note
        self.updatedAt = updatedAt
    }
}

/// 睡眠の記録。DailyPage とは独立。日付は dateKey でつなぐだけ。
///
/// 同じ dateKey で2つ作らない。作るときは findOrCreate を通す（T-105）。
/// 日付は「起きた日」の文字列を入れる（変換のコードは T-102。ここでは文字列のまま持つ）。
/// ユニーク制約（同じ値を禁止する印）は付けない。
/// 日ページを消しても、睡眠の記録は残す。
@Model
final class SleepEntry {
    /// 睡眠1件を見分ける ID。
    var id: UUID = UUID()
    /// 起きた日（例：`2026-10-27`）。
    var dateKey: String = ""
    /// 睡眠時間。0.5 刻みを想定。標準は 0。
    var hours: Double = 0
    /// 睡眠の質（1〜5）。いまは将来用。無くてよい。
    var quality: Int? = nil
    /// 最後に更新した時刻。
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        dateKey: String = "",
        hours: Double = 0,
        quality: Int? = nil,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.dateKey = dateKey
        self.hours = hours
        self.quality = quality
        self.updatedAt = updatedAt
    }
}
