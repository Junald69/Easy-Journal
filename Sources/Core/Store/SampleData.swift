import Foundation
import SwiftData

/// 画面確認用の見本。中身は毎回同じ。乱数は使わない。いまの時刻も使わない。
///
/// 入れる月は 2026年10月だけ。日付キーは `DateKey` の `yyyy-MM` / `yyyy-MM-dd`。
/// ページ、1行、気分、睡眠、タスク、繰越は、JournalStore（保存係）の関数だけを使う。
/// 習慣の定義（`Habit`）を作る関数は保存係に無い。定義だけは、既存の保存テストと同じく
/// 保存先へ1件足し、チェックの付け外しは `toggleHabit` だけを使う。
///
/// もう一度呼んでも増やさない。2026-10 の月ページが既にあれば、中身が足りなくても何もしない。
/// チェックを付け直すと、`toggleHabit` は外してしまうため、途中からは再開しない。
/// 保存係は操作のたびに保存する。途中で失敗すると、そこまでの分は残る。一括では戻らない。
/// 呼ぶ側が、メモリ上の保存先のときだけ呼ぶ。この関数自体は保存先の種類を見ない。
enum SampleData {
    /// 見本の月。`yyyy-MM`。
    static let monthKey = "2026-10"

    /// 見本を入れてよいか。要求があり、かつメモリ上の保存先のときだけ true。
    ///
    /// 本物の保存先（App Group）のときは false。記録を汚さない。
    static func shouldInstall(sampleDataRequested: Bool, inMemoryStore: Bool) -> Bool {
        if sampleDataRequested == false {
            return false
        }
        if inMemoryStore == false {
            return false
        }
        return true
    }

    /// 見本を入れる。`context` は `store` を作ったときと同じ読み書きの窓口にする。
    ///
    /// 違う窓口だと、習慣の定義を保存係が見つけられない。
    static func install(into store: JournalStore, context: ModelContext) throws {
        if try store.findMonthly(monthKey: SampleData.monthKey) != nil {
            return
        }
        let monthly = try store.findOrCreateMonthly(monthKey: SampleData.monthKey)
        let water = Habit(name: "水を飲む", shortLabel: "水", sortOrder: 0)
        let walk = Habit(name: "歩く", shortLabel: "歩", sortOrder: 1)
        context.insert(water)
        context.insert(walk)
        water.monthly = monthly
        walk.monthly = monthly

        for sample in logSamples {
            try store.setLogLine(dateKey: sample.dateKey, text: sample.text)
        }
        for dateKey in explicitDailyDateKeys {
            _ = try store.findOrCreateDaily(dateKey: dateKey, createdBy: .user)
        }
        for sample in moodSamples {
            try store.setMood(dateKey: sample.dateKey, level: sample.level)
        }
        for sample in sleepSamples {
            try store.setSleep(dateKey: sample.dateKey, hours: sample.hours)
        }
        for dateKey in waterDateKeys {
            try turnHabitOn(habitID: water.id, dateKey: dateKey, store: store)
        }
        for dateKey in walkDateKeys {
            try turnHabitOn(habitID: walk.id, dateKey: dateKey, store: store)
        }
        for sample in dailyTaskSamples {
            let task = try store.addDailyTask(
                dateKey: sample.dateKey,
                title: sample.title,
                createdBy: .user
            )
            try advance(taskID: task.id, taps: sample.progressTaps, store: store)
            if sample.carryToNextDay {
                _ = try store.carryForward(taskID: task.id)
            }
        }
        for sample in monthlyTaskSamples {
            let task = try store.addMonthlyTask(monthKey: SampleData.monthKey, title: sample.title)
            try advance(taskID: task.id, taps: sample.progressTaps, store: store)
        }
    }

    /// チェックを1回だけ付ける。もう付いていると `toggleHabit` は外すので、外れたら失敗にする。
    private static func turnHabitOn(habitID: UUID, dateKey: String, store: JournalStore) throws {
        let turnedOn = try store.toggleHabit(habitID: habitID, dateKey: dateKey)
        if turnedOn == false {
            throw SampleDataError.habitDidNotTurnOn(dateKey)
        }
    }

    /// 進み具合を、指定した回数だけ進める。0 なら未完のまま。1 で一部、2 で完了。
    private static func advance(taskID: UUID, taps: Int, store: JournalStore) throws {
        if taps <= 0 {
            return
        }
        for _ in 0..<taps {
            _ = try store.cycleProgress(taskID: taskID)
        }
    }

    // MARK: - 固定の中身

    /// 1行を入れる日。20件。空の日は 5, 12, 19, 20, 22, 23, 25, 26, 27, 29, 30 の11件。
    /// 最初の日、最後の日、土曜、日曜を含む。
    private static let logSamples: [LogSample] = [
        LogSample(dateKey: "2026-10-01", text: "月初"),
        LogSample(dateKey: "2026-10-02", text: "Review the October plan 2026"),
        LogSample(dateKey: "2026-10-03", text: "土曜の散歩 🚶"),
        LogSample(dateKey: "2026-10-04", text: "日曜は休む"),
        LogSample(dateKey: "2026-10-06", text: "メモ"),
        LogSample(dateKey: "2026-10-07", text: "ABC123"),
        LogSample(
            dateKey: "2026-10-08",
            text: "きょうは窓を開けて、長い文章が折り返されるかを見るための記録を書いておく。画面の端まで続く一行です。"
        ),
        LogSample(dateKey: "2026-10-09", text: "会議"),
        LogSample(dateKey: "2026-10-10", text: "洗濯"),
        LogSample(dateKey: "2026-10-11", text: "読書"),
        LogSample(dateKey: "2026-10-13", text: "コーヒー"),
        LogSample(dateKey: "2026-10-14", text: "買い物"),
        LogSample(dateKey: "2026-10-15", text: "Mid-month note"),
        LogSample(dateKey: "2026-10-16", text: "散歩"),
        LogSample(dateKey: "2026-10-17", text: "手紙を書く"),
        LogSample(dateKey: "2026-10-18", text: "短"),
        LogSample(dateKey: "2026-10-21", text: "週の始まり"),
        LogSample(dateKey: "2026-10-24", text: "資料"),
        LogSample(dateKey: "2026-10-28", text: "振り返り前"),
        LogSample(dateKey: "2026-10-31", text: "月末。October ends.")
    ]

    /// 人が開く日ページ。10/21 はここには入れない。繰越が翌日として作る。
    private static let explicitDailyDateKeys: [String] = [
        "2026-10-01",
        "2026-10-05",
        "2026-10-12",
        "2026-10-20",
        "2026-10-27",
        "2026-10-31"
    ]

    private static let moodSamples: [MoodSample] = [
        MoodSample(dateKey: "2026-10-01", level: 4),
        MoodSample(dateKey: "2026-10-05", level: 2),
        MoodSample(dateKey: "2026-10-27", level: 5)
    ]

    private static let sleepSamples: [SleepSample] = [
        SleepSample(dateKey: "2026-10-01", hours: 7.5),
        SleepSample(dateKey: "2026-10-05", hours: 6.0),
        SleepSample(dateKey: "2026-10-27", hours: 8.0)
    ]

    /// 水を飲む、をオンにする日。各日1回だけ。
    private static let waterDateKeys: [String] = [
        "2026-10-01",
        "2026-10-03",
        "2026-10-06",
        "2026-10-11",
        "2026-10-20"
    ]

    /// 歩く、をオンにする日。各日1回だけ。
    private static let walkDateKeys: [String] = [
        "2026-10-04",
        "2026-10-12",
        "2026-10-31"
    ]

    /// progressTaps は `cycleProgress` の回数。0 未完、1 一部、2 完了。3 は元に戻るので使わない。
    private static let dailyTaskSamples: [DailyTaskSample] = [
        DailyTaskSample(
            dateKey: "2026-10-01",
            title: "日記を開く",
            progressTaps: 0,
            carryToNextDay: false
        ),
        DailyTaskSample(
            dateKey: "2026-10-12",
            title: "画面の折り返しを確認するための、少し長めのタスク文です。日本語と English 123。",
            progressTaps: 1,
            carryToNextDay: false
        ),
        DailyTaskSample(
            dateKey: "2026-10-20",
            title: "牛乳を買う 🥛",
            progressTaps: 0,
            carryToNextDay: true
        ),
        DailyTaskSample(
            dateKey: "2026-10-27",
            title: "Done",
            progressTaps: 2,
            carryToNextDay: false
        ),
        DailyTaskSample(
            dateKey: "2026-10-31",
            title: "短",
            progressTaps: 0,
            carryToNextDay: false
        )
    ]

    private static let monthlyTaskSamples: [MonthlyTaskSample] = [
        MonthlyTaskSample(title: "今月のねらい", progressTaps: 0),
        MonthlyTaskSample(title: "読書を進める", progressTaps: 1),
        MonthlyTaskSample(title: "部屋の片付け", progressTaps: 2),
        MonthlyTaskSample(title: "Q4 review", progressTaps: 0)
    ]

    private struct LogSample {
        let dateKey: String
        let text: String
    }

    private struct MoodSample {
        let dateKey: String
        let level: Int
    }

    private struct SleepSample {
        let dateKey: String
        let hours: Double
    }

    private struct DailyTaskSample {
        let dateKey: String
        let title: String
        let progressTaps: Int
        let carryToNextDay: Bool
    }

    private struct MonthlyTaskSample {
        let title: String
        let progressTaps: Int
    }
}

/// 見本を入れている途中の失敗。保存係のエラーとは別に、チェックが付かなかったときだけ。
enum SampleDataError: Error, Equatable {
    /// `toggleHabit` が false を返した。その日はオンにならなかった。
    case habitDidNotTurnOn(String)
}
