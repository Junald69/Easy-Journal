import Foundation

/// Tracker 用の値。モデルを直接編集せず、保存後に読み直す。
struct MonthlyTrackerContent: Equatable {
    struct Column: Equatable, Identifiable {
        let id: UUID
        let name: String
        let shortLabel: String
    }
    struct Check: Hashable {
        let habitID: UUID
        let dateKey: String
    }
    let columns: [Column]
    let checks: Set<Check>
}

enum MonthlyTrackerRules {
    /// 固定長の有効な日付キー同士だけを比較する。日付変更時も渡された今日で再判定する。
    static func mayToggle(dateKey: String, monthKey: String, todayKey: String) -> Bool {
        DateKey.isValidDayKey(dateKey)
            && DateKey.isValidDayKey(todayKey)
            && DateKey.isValidMonthKey(monthKey)
            && DateKey.monthKey(ofDayKey: dateKey) == monthKey
            && dateKey <= todayKey
    }
}
