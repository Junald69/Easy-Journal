import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// 見本データ。メモリ上の保存だけ。App Group は使わない。
final class SampleDataTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    /// 要求があり、メモリ上のときだけ true。本物の保存先や、要求が無いときは false。
    func testShouldInstallOnlyWhenSampleRequestedAndInMemory() {
        XCTAssertTrue(
            SampleData.shouldInstall(sampleDataRequested: true, inMemoryStore: true)
        )
        XCTAssertFalse(
            SampleData.shouldInstall(sampleDataRequested: true, inMemoryStore: false)
        )
        XCTAssertFalse(
            SampleData.shouldInstall(sampleDataRequested: false, inMemoryStore: true)
        )
        XCTAssertFalse(
            SampleData.shouldInstall(sampleDataRequested: false, inMemoryStore: false)
        )
    }

    /// 2026年10月の見本が、決めた件数と文字で入る。最初の日、最後の日、空の日、土日を含む。
    func testInstallWritesFixedOctoberSample() throws {
        let (store, context, _) = try makeStore()
        try SampleData.install(into: store, context: context)

        XCTAssertEqual(SampleData.monthKey, "2026-10")
        let monthlies = try context.fetch(FetchDescriptor<MonthlyPage>())
        XCTAssertEqual(monthlies.count, 1)
        XCTAssertEqual(monthlies.first?.monthKey, "2026-10")
        XCTAssertNil(try store.findMonthly(monthKey: "2026-09"))
        XCTAssertNil(try store.findMonthly(monthKey: "2026-11"))

        let days = DateKey.dayKeys(inMonth: "2026-10")
        XCTAssertEqual(days.count, 31)
        var filledLogDays = 0
        var emptyLogDays = 0
        for dateKey in days {
            let stored = try store.logLine(dateKey: dateKey)
            if let expected = expectedLogText(on: dateKey) {
                XCTAssertEqual(stored?.text, expected)
                filledLogDays += 1
            } else {
                XCTAssertNil(stored)
                emptyLogDays += 1
            }
        }
        XCTAssertEqual(filledLogDays, 20)
        XCTAssertEqual(emptyLogDays, 11)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 20)

        XCTAssertEqual(try store.logLine(dateKey: "2026-10-01")?.text, "月初")
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-31")?.text, "月末。October ends.")
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-03")?.text, "土曜の散歩 🚶")
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-04")?.text, "日曜は休む")
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-18")?.text, "短")
        XCTAssertEqual(
            try store.logLine(dateKey: "2026-10-08")?.text,
            "きょうは窓を開けて、長い文章が折り返されるかを見るための記録を書いておく。画面の端まで続く一行です。"
        )
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-02")?.text, "Review the October plan 2026")
        XCTAssertNil(try store.logLine(dateKey: "2026-10-19"))
        XCTAssertNil(try store.logLine(dateKey: "2026-10-25"))

        let expectedDailyDateKeys = [
            "2026-10-01",
            "2026-10-05",
            "2026-10-12",
            "2026-10-20",
            "2026-10-21",
            "2026-10-27",
            "2026-10-31"
        ]
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), expectedDailyDateKeys.count)
        for dateKey in days {
            let daily = try store.findDaily(dateKey: dateKey)
            if expectedDailyDateKeys.contains(dateKey) {
                XCTAssertNotNil(daily)
            } else {
                XCTAssertNil(daily)
            }
        }
        XCTAssertNil(try store.findDaily(dateKey: "2026-10-02"))
        XCTAssertNil(try store.findDaily(dateKey: "2026-10-19"))
        XCTAssertNotNil(try store.findDaily(dateKey: "2026-10-01"))
        XCTAssertNotNil(try store.findDaily(dateKey: "2026-10-31"))
        XCTAssertEqual(try store.findDaily(dateKey: "2026-10-01")?.page?.createdBy, .user)
        XCTAssertEqual(try store.findDaily(dateKey: "2026-10-21")?.page?.createdBy, .carryOver)

        XCTAssertEqual(try store.mood(dateKey: "2026-10-01")?.level, 4)
        XCTAssertEqual(try store.mood(dateKey: "2026-10-05")?.level, 2)
        XCTAssertEqual(try store.mood(dateKey: "2026-10-27")?.level, 5)
        XCTAssertNil(try store.mood(dateKey: "2026-10-02"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 3)

        XCTAssertEqual(try store.sleep(dateKey: "2026-10-01")?.hours, 7.5)
        XCTAssertEqual(try store.sleep(dateKey: "2026-10-05")?.hours, 6.0)
        XCTAssertEqual(try store.sleep(dateKey: "2026-10-27")?.hours, 8.0)
        XCTAssertNil(try store.sleep(dateKey: "2026-10-03"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 3)

        XCTAssertEqual(
            try habitEntryDateKeys(named: "水を飲む", in: context),
            ["2026-10-01", "2026-10-03", "2026-10-06", "2026-10-11", "2026-10-20"]
        )
        XCTAssertEqual(
            try habitEntryDateKeys(named: "歩く", in: context),
            ["2026-10-04", "2026-10-12", "2026-10-31"]
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 8)
        XCTAssertNil(try store.findDaily(dateKey: "2026-10-03"))

        var dailyProgresses: Set<TaskProgress> = []
        let opening = try tasks(on: "2026-10-01", store: store)
        XCTAssertEqual(opening.count, 1)
        XCTAssertEqual(opening.first?.title, "日記を開く")
        XCTAssertEqual(opening.first?.progress, .open)
        XCTAssertEqual(opening.first?.isCarriedForward, false)
        XCTAssertNil(opening.first?.completedAt)
        if let progress = opening.first?.progress {
            dailyProgresses.insert(progress)
        }

        let longTask = try tasks(on: "2026-10-12", store: store)
        XCTAssertEqual(longTask.count, 1)
        XCTAssertEqual(
            longTask.first?.title,
            "画面の折り返しを確認するための、少し長めのタスク文です。日本語と English 123。"
        )
        XCTAssertEqual(longTask.first?.progress, .partial)
        XCTAssertEqual(longTask.first?.isCarriedForward, false)
        if let progress = longTask.first?.progress {
            dailyProgresses.insert(progress)
        }

        let sourceTasks = try tasks(on: "2026-10-20", store: store)
        XCTAssertEqual(sourceTasks.count, 1)
        let source = sourceTasks.first
        XCTAssertEqual(source?.title, "牛乳を買う 🥛")
        XCTAssertEqual(source?.progress, .open)
        XCTAssertEqual(source?.isCarriedForward, true)
        XCTAssertNil(source?.carriedFromTaskID)
        XCTAssertNotNil(source?.carriedToTaskID)
        if let progress = source?.progress {
            dailyProgresses.insert(progress)
        }
        if let sourceProgress = source?.progress, let sourceCarried = source?.isCarriedForward {
            let carriedSymbol = TaskRules.symbol(
                progress: sourceProgress,
                isCarriedForward: sourceCarried
            )
            let expectedSymbol: TaskRules.Symbol? = .openCarried
            XCTAssertEqual(carriedSymbol, expectedSymbol)
        } else {
            XCTFail("繰越元の進み具合が取れませんでした")
        }

        let copyTasks = try tasks(on: "2026-10-21", store: store)
        XCTAssertEqual(copyTasks.count, 1)
        let copy = copyTasks.first
        XCTAssertEqual(copy?.title, "牛乳を買う 🥛")
        XCTAssertEqual(copy?.progress, .open)
        XCTAssertEqual(copy?.isCarriedForward, false)
        XCTAssertNil(copy?.carriedToTaskID)
        XCTAssertEqual(copy?.carriedFromTaskID, source?.id)
        XCTAssertEqual(source?.carriedToTaskID, copy?.id)
        if let progress = copy?.progress {
            dailyProgresses.insert(progress)
        }

        let doneTasks = try tasks(on: "2026-10-27", store: store)
        XCTAssertEqual(doneTasks.count, 1)
        XCTAssertEqual(doneTasks.first?.title, "Done")
        XCTAssertEqual(doneTasks.first?.progress, .done)
        XCTAssertEqual(doneTasks.first?.isCarriedForward, false)
        XCTAssertNotNil(doneTasks.first?.completedAt)
        if let progress = doneTasks.first?.progress {
            dailyProgresses.insert(progress)
        }

        let shortTasks = try tasks(on: "2026-10-31", store: store)
        XCTAssertEqual(shortTasks.count, 1)
        XCTAssertEqual(shortTasks.first?.title, "短")
        XCTAssertEqual(shortTasks.first?.progress, .open)
        if let progress = shortTasks.first?.progress {
            dailyProgresses.insert(progress)
        }
        XCTAssertEqual(dailyProgresses, Set([TaskProgress.open, TaskProgress.partial, TaskProgress.done]))

        guard let monthly = try store.findMonthly(monthKey: "2026-10") else {
            XCTFail("2026-10 の月ページがありません")
            return
        }
        let monthlyTasks = try store.tasks(onMonthly: monthly)
        XCTAssertEqual(monthlyTasks.count, 4)
        XCTAssertGreaterThanOrEqual(monthlyTasks.count, 3)
        var monthlyProgresses: Set<TaskProgress> = []
        for task in monthlyTasks {
            monthlyProgresses.insert(task.progress)
        }
        XCTAssertEqual(
            monthlyProgresses,
            Set([TaskProgress.open, TaskProgress.partial, TaskProgress.done])
        )
        XCTAssertEqual(monthlyTasks.map { task in task.title }, [
            "今月のねらい",
            "読書を進める",
            "部屋の片付け",
            "Q4 review"
        ])
        XCTAssertEqual(monthlyTasks.map { task in task.progress }, [.open, .partial, .done, .open])

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 10)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 17)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 8)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 8)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 1)
    }

    /// 2回入れても、件数も中身も変わらない。
    func testInstallTwiceKeepsTheSameCounts() throws {
        let (store, context, _) = try makeStore()
        try SampleData.install(into: store, context: context)
        let counts = try storedCounts(in: context)
        let before = try fingerprint(store: store, context: context)

        try SampleData.install(into: store, context: context)

        XCTAssertEqual(try storedCounts(in: context), counts)
        XCTAssertEqual(try fingerprint(store: store, context: context), before)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 20)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 7)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 8)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 10)
    }

    /// 時計を変えても、見本の月と中身は同じ。
    func testInstallUsesTheSameContentForDifferentNow() throws {
        let early = Date(timeIntervalSince1970: 0)
        let late = Date(timeIntervalSince1970: 2_000_000_000)
        let (earlyStore, earlyContext, _) = try makeStore(now: early)
        let (lateStore, lateContext, _) = try makeStore(now: late)
        try SampleData.install(into: earlyStore, context: earlyContext)
        try SampleData.install(into: lateStore, context: lateContext)

        XCTAssertEqual(
            try fingerprint(store: earlyStore, context: earlyContext),
            try fingerprint(store: lateStore, context: lateContext)
        )
        XCTAssertEqual(try earlyStore.findMonthly(monthKey: "2026-10")?.monthKey, "2026-10")
        XCTAssertEqual(try lateStore.findMonthly(monthKey: "2026-10")?.monthKey, "2026-10")
        XCTAssertNil(try earlyStore.findMonthly(monthKey: "1970-01"))
        XCTAssertNil(try lateStore.findMonthly(monthKey: "2033-05"))
        XCTAssertEqual(try earlyStore.logLine(dateKey: "2026-10-03")?.text, "土曜の散歩 🚶")
        XCTAssertEqual(try lateStore.logLine(dateKey: "2026-10-03")?.text, "土曜の散歩 🚶")
        XCTAssertEqual(try earlyContext.fetchCount(FetchDescriptor<DailyPage>()), 7)
        XCTAssertEqual(try lateContext.fetchCount(FetchDescriptor<DailyPage>()), 7)
    }

    /// 見本の月ページが先にあると、空のままでも足さない。
    func testInstallSkipsWhenOctoberMonthlyAlreadyExists() throws {
        let (store, context, _) = try makeStore()
        _ = try store.findOrCreateMonthly(monthKey: "2026-10")
        let counts = try storedCounts(in: context)

        try SampleData.install(into: store, context: context)

        XCTAssertEqual(try storedCounts(in: context), counts)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 0)
    }

    /// 途中の保存が失敗すると、そこまでは残る。もう一度呼んでも、足りない分は足さない。
    ///
    /// 保存の回数は、いまの JournalStore の動きに合わせている。
    /// 手帳の保存、月ページの保存、最初の1行の保存、の3回が成功したあとで失敗させる。
    /// 習慣の定義は、最初の1行と一緒に保存される。
    func testInstallKeepsPartialRowsWhenALaterSaveFails() throws {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let counter = SaveCounter()
        let failingStore = JournalStore(
            context: context,
            now: { self.fixedNow },
            save: { modelContext in
                if counter.successfulSaves >= 3 {
                    throw SampleSaveError.forced
                }
                try modelContext.save()
                counter.successfulSaves += 1
            }
        )

        XCTAssertThrowsError(try SampleData.install(into: failingStore, context: context)) { error in
            XCTAssertEqual(error as? SampleSaveError, .forced)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(counter.successfulSaves, 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 1)
        XCTAssertEqual(try storeLineCount(on: "2026-10-01", in: context), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MonthlyLogLine>()).first?.text, "月初")
        XCTAssertEqual(try storeLineCount(on: "2026-10-02", in: context), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0)

        let counts = try storedCounts(in: context)
        let healthyStore = JournalStore(context: context, now: { self.fixedNow })
        try SampleData.install(into: healthyStore, context: context)

        XCTAssertEqual(try storedCounts(in: context), counts)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertNil(try healthyStore.logLine(dateKey: "2026-10-02"))
        XCTAssertEqual(try healthyStore.logLine(dateKey: "2026-10-01")?.text, "月初")
    }

    // MARK: - ヘルパー

    private func makeStore(
        now: Date? = nil
    ) throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let instant = now ?? fixedNow
        let store = JournalStore(context: context, now: { instant })
        return (store, context, container)
    }

    private func tasks(on dateKey: String, store: JournalStore) throws -> [JournalTask] {
        guard let daily = try store.findDaily(dateKey: dateKey) else {
            return []
        }
        return try store.tasks(onDaily: daily)
    }

    private func habitEntryDateKeys(named name: String, in context: ModelContext) throws -> [String] {
        let habits = try context.fetch(FetchDescriptor<Habit>())
        var matchingIDs: [UUID] = []
        for habit in habits {
            if habit.name == name {
                matchingIDs.append(habit.id)
            }
        }
        let entries = try context.fetch(FetchDescriptor<HabitEntry>())
        var dateKeys: [String] = []
        for entry in entries {
            if matchingIDs.contains(entry.habitID) {
                dateKeys.append(entry.dateKey)
            }
        }
        return dateKeys.sorted()
    }

    private func storedCounts(in context: ModelContext) throws -> [String: Int] {
        [
            "journal": try context.fetchCount(FetchDescriptor<Journal>()),
            "page": try context.fetchCount(FetchDescriptor<Page>()),
            "daily": try context.fetchCount(FetchDescriptor<DailyPage>()),
            "monthly": try context.fetchCount(FetchDescriptor<MonthlyPage>()),
            "log": try context.fetchCount(FetchDescriptor<MonthlyLogLine>()),
            "mood": try context.fetchCount(FetchDescriptor<MoodEntry>()),
            "sleep": try context.fetchCount(FetchDescriptor<SleepEntry>()),
            "habit": try context.fetchCount(FetchDescriptor<Habit>()),
            "habitEntry": try context.fetchCount(FetchDescriptor<HabitEntry>()),
            "task": try context.fetchCount(FetchDescriptor<JournalTask>()),
            "history": try context.fetchCount(FetchDescriptor<TaskHistory>()),
            "link": try context.fetchCount(FetchDescriptor<PageLink>())
        ]
    }

    /// 時計や ID が違っても比べられる、見本の中身。
    private func fingerprint(store: JournalStore, context: ModelContext) throws -> [String] {
        var lines: [String] = []
        let monthlies = try context.fetch(FetchDescriptor<MonthlyPage>())
        for monthly in monthlies {
            lines.append("monthly|" + monthly.monthKey)
            let monthlyTasks = try store.tasks(onMonthly: monthly)
            for task in monthlyTasks {
                lines.append("month-task|" + task.title + "|" + task.progressRaw)
            }
        }
        let days = DateKey.dayKeys(inMonth: "2026-10")
        for dateKey in days {
            if let logLine = try store.logLine(dateKey: dateKey) {
                lines.append("log|" + dateKey + "|" + logLine.text)
            }
            if let mood = try store.mood(dateKey: dateKey) {
                lines.append("mood|" + dateKey + "|" + String(mood.level))
            }
            if let sleep = try store.sleep(dateKey: dateKey) {
                lines.append("sleep|" + dateKey + "|" + String(sleep.hours))
            }
            if let daily = try store.findDaily(dateKey: dateKey) {
                let createdByRaw = daily.page?.createdByRaw ?? ""
                lines.append("daily|" + dateKey + "|" + createdByRaw)
                let dailyTasks = try store.tasks(onDaily: daily)
                for task in dailyTasks {
                    let carried = task.isCarriedForward ? "carried" : "plain"
                    let hasDestination = task.carriedToTaskID == nil ? "no-to" : "has-to"
                    let hasSource = task.carriedFromTaskID == nil ? "no-from" : "has-from"
                    lines.append(
                        "task|" + dateKey + "|" + task.title + "|" + task.progressRaw
                            + "|" + carried + "|" + hasDestination + "|" + hasSource
                    )
                }
            }
        }
        lines.append(contentsOf: try habitFingerprints(in: context))
        return lines.sorted()
    }

    private func habitFingerprints(in context: ModelContext) throws -> [String] {
        let habits = try context.fetch(FetchDescriptor<Habit>())
        var nameByID: [UUID: String] = [:]
        for habit in habits {
            nameByID[habit.id] = habit.name
        }
        let entries = try context.fetch(FetchDescriptor<HabitEntry>())
        var lines: [String] = []
        for entry in entries {
            let name = nameByID[entry.habitID] ?? ""
            let done = entry.isDone ? "1" : "0"
            lines.append("habit|" + name + "|" + entry.dateKey + "|" + done)
        }
        return lines
    }

    private func storeLineCount(on dateKey: String, in context: ModelContext) throws -> Int {
        let stored = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        var count = 0
        for line in stored {
            if line.dateKey == dateKey {
                count += 1
            }
        }
        return count
    }

    /// 1行の期待値。無い日は nil。テスト側に文字を書いて、実装が違えば落ちるようにする。
    private func expectedLogText(on dateKey: String) -> String? {
        let expected: [String: String] = [
            "2026-10-01": "月初",
            "2026-10-02": "Review the October plan 2026",
            "2026-10-03": "土曜の散歩 🚶",
            "2026-10-04": "日曜は休む",
            "2026-10-06": "メモ",
            "2026-10-07": "ABC123",
            "2026-10-08": "きょうは窓を開けて、長い文章が折り返されるかを見るための記録を書いておく。画面の端まで続く一行です。",
            "2026-10-09": "会議",
            "2026-10-10": "洗濯",
            "2026-10-11": "読書",
            "2026-10-13": "コーヒー",
            "2026-10-14": "買い物",
            "2026-10-15": "Mid-month note",
            "2026-10-16": "散歩",
            "2026-10-17": "手紙を書く",
            "2026-10-18": "短",
            "2026-10-21": "週の始まり",
            "2026-10-24": "資料",
            "2026-10-28": "振り返り前",
            "2026-10-31": "月末。October ends."
        ]
        return expected[dateKey]
    }

    private final class SaveCounter {
        var successfulSaves = 0
    }

    private enum SampleSaveError: Error, Equatable {
        case forced
    }
}
