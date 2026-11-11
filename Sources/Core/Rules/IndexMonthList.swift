import Foundation

/// Index（ページ一覧）に、その月を出すか。画面は持たない。保存しない。
///
/// 月は ◀▶ で自由に開ける。一覧に出すかは、ここだけで決める。
/// 空の月ページが保存されているだけでは出さない。記録が1つでもあれば出す。
/// 今月は、記録が無くても出す。
enum IndexMonthList {
    /// その月に、実際の記録があるか。空の月ページそのものは数えない。
    struct Records: Equatable {
        var hasLog: Bool = false
        var hasMonthlyTask: Bool = false
        var hasHabit: Bool = false
        var hasSleep: Bool = false
        var hasMood: Bool = false
        var hasDaily: Bool = false
        /// いまの月なら true。記録が無くても一覧に出す。
        var isCurrentMonth: Bool = false
    }

    /// 一覧に出すとき true。
    static func includes(_ records: Records) -> Bool {
        if records.isCurrentMonth {
            return true
        }
        if records.hasLog {
            return true
        }
        if records.hasMonthlyTask {
            return true
        }
        if records.hasHabit {
            return true
        }
        if records.hasSleep {
            return true
        }
        if records.hasMood {
            return true
        }
        if records.hasDaily {
            return true
        }
        return false
    }
}
