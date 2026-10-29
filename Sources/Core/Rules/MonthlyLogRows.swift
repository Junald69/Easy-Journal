/// 月の左ページの、1日1行。画面には依存しない。
struct MonthlyLogRow: Equatable {
    /// 日付キー（`yyyy-MM-dd`）。
    let dateKey: String
    /// 日の数字。1 から、その月の日数まで。
    let dayNumber: Int
    /// 曜日。日曜が 1。`DateKey.Weekday` と同じ。
    let weekday: DateKey.Weekday
    /// 1行の文章。無い日は空文字。
    let text: String
    /// 渡された「今日」の日付キーと、この行の日付キーが同じとき true。
    let isToday: Bool
    /// 土曜か日曜のとき true。
    let isWeekend: Bool
    /// その日に、中身のある Daily があるとき true。
    let hasDaily: Bool
}

/// 月の行を作るルール。保存しない。画面を持たない。
///
/// 日数と曜日は `DateKey` が決める。`Date` 同士を比べて「同じ日か」は決めない。
/// 月に属さない日付キーは、行を増やさない。不正な日付キーは無視する。クラッシュしない。
enum MonthlyLogRows {
    /// その月の日数ぶんの行を、1日から順に返す。不正な月キーなら空。
    ///
    /// 「今日」は、もう計算済みの日付キー（`todayKey`）で受け取る。
    /// ここでは暦を使って日付を動かさない。
    static func make(
        monthKey: String,
        textByDateKey: [String: String],
        dailyDateKeys: Set<String>,
        todayKey: String
    ) -> [MonthlyLogRow] {
        let dateKeys = DateKey.dayKeys(inMonth: monthKey)
        var rows: [MonthlyLogRow] = []
        for (offset, dateKey) in dateKeys.enumerated() {
            guard let dayOfWeek = DateKey.weekday(ofDayKey: dateKey) else {
                continue
            }
            let weekend = dayOfWeek == .saturday || dayOfWeek == .sunday
            let lineText = textByDateKey[dateKey] ?? ""
            let row = MonthlyLogRow(
                dateKey: dateKey,
                dayNumber: offset + 1,
                weekday: dayOfWeek,
                text: lineText,
                isToday: dateKey == todayKey,
                isWeekend: weekend,
                hasDaily: dailyDateKeys.contains(dateKey)
            )
            rows.append(row)
        }
        return rows
    }
}
