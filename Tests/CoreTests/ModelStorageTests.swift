import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// モデルの保存と読み戻し。
///
/// すべてメモリ上だけ、または一時フォルダのファイル。App Group は使わない。
final class ModelStorageTests: XCTestCase {
    func testEachModelCanBeSavedAndReadBack() throws {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let journal = Journal(title: "往復の手帳", weekStartsOnMonday: false)
        let page = Page(dateKey: "2026-11-01", monthKey: "2026-11")
        page.kind = .monthly
        page.createdBy = .system
        let monthly = MonthlyPage(monthKey: "2026-11", reflection: "月のメモ")
        let logLine = MonthlyLogLine(dateKey: "2026-11-02", text: "ログの一行")
        let daily = DailyPage(
            dateKey: "2026-11-03",
            memo: "今日のメモ",
            isTaskListCollapsed: true,
            textColorHex: "#112233"
        )
        daily.paperStyle = .lined
        daily.background = .black
        let carriedFrom = UUID()
        let carriedTo = UUID()
        let task = JournalTask(
            title: "往復タスク",
            isCarriedForward: true,
            carriedFromTaskID: carriedFrom,
            carriedToTaskID: carriedTo,
            sortOrder: 3
        )
        task.scope = .monthly
        task.progress = .done
        let history = TaskHistory(
            taskID: task.id,
            relatedTaskID: carriedTo,
            relatedDateKey: "2026-11-04"
        )
        history.action = .edited
        history.fromProgress = .open
        history.toProgress = .partial
        let previousHabitID = UUID()
        let habit = Habit(
            name: "散歩",
            shortLabel: "歩",
            colorHex: "#00AA00",
            sortOrder: 2,
            carriedFromHabitID: previousHabitID
        )
        let habitEntry = HabitEntry(habitID: habit.id, dateKey: "2026-11-04", isDone: false)
        let mood = MoodEntry(dateKey: "2026-11-05", level: 1, note: "低い")
        let sleep = SleepEntry(dateKey: "2026-11-06", hours: 6.5, quality: 2)
        let link = PageLink(fromPageID: page.id, toPageID: UUID())
        link.type = .carryOver

        let journalID = journal.id
        context.insert(journal)
        context.insert(page)
        context.insert(monthly)
        context.insert(logLine)
        context.insert(daily)
        context.insert(task)
        context.insert(history)
        context.insert(habit)
        context.insert(habitEntry)
        context.insert(mood)
        context.insert(sleep)
        context.insert(link)
        try context.save()

        let journals = try context.fetch(FetchDescriptor<Journal>())
        XCTAssertEqual(journals.count, 1)
        XCTAssertEqual(journals.first?.id, journalID)
        XCTAssertEqual(journals.first?.title, "往復の手帳")
        XCTAssertEqual(journals.first?.weekStartsOnMonday, false)

        let pages = try context.fetch(FetchDescriptor<Page>())
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.dateKey, "2026-11-01")
        XCTAssertEqual(pages.first?.monthKey, "2026-11")
        XCTAssertEqual(pages.first?.kindRaw, "monthly")
        XCTAssertEqual(pages.first?.kind, .monthly)
        XCTAssertEqual(pages.first?.createdBy, .system)

        let monthlies = try context.fetch(FetchDescriptor<MonthlyPage>())
        XCTAssertEqual(monthlies.count, 1)
        XCTAssertEqual(monthlies.first?.monthKey, "2026-11")
        XCTAssertEqual(monthlies.first?.reflection, "月のメモ")

        let lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.dateKey, "2026-11-02")
        XCTAssertEqual(lines.first?.text, "ログの一行")

        let dailies = try context.fetch(FetchDescriptor<DailyPage>())
        XCTAssertEqual(dailies.count, 1)
        XCTAssertEqual(dailies.first?.dateKey, "2026-11-03")
        XCTAssertEqual(dailies.first?.memo, "今日のメモ")
        XCTAssertEqual(dailies.first?.isTaskListCollapsed, true)
        XCTAssertEqual(dailies.first?.paperStyleRaw, "lined")
        XCTAssertEqual(dailies.first?.paperStyle, .lined)
        XCTAssertEqual(dailies.first?.backgroundRaw, "black")
        XCTAssertEqual(dailies.first?.background, .black)
        XCTAssertEqual(dailies.first?.textColorHex, "#112233")

        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "往復タスク")
        XCTAssertEqual(tasks.first?.scopeRaw, "monthly")
        XCTAssertEqual(tasks.first?.scope, .monthly)
        XCTAssertEqual(tasks.first?.progressRaw, "done")
        XCTAssertEqual(tasks.first?.progress, .done)
        XCTAssertEqual(tasks.first?.isCarriedForward, true)
        XCTAssertEqual(tasks.first?.carriedFromTaskID, carriedFrom)
        XCTAssertEqual(tasks.first?.carriedToTaskID, carriedTo)
        XCTAssertEqual(tasks.first?.sortOrder, 3)

        let histories = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.taskID, task.id)
        XCTAssertEqual(histories.first?.actionRaw, "edited")
        XCTAssertEqual(histories.first?.action, .edited)
        XCTAssertEqual(histories.first?.fromProgressRaw, "open")
        XCTAssertEqual(histories.first?.fromProgress, .open)
        XCTAssertEqual(histories.first?.toProgressRaw, "partial")
        XCTAssertEqual(histories.first?.toProgress, .partial)
        XCTAssertEqual(histories.first?.relatedTaskID, carriedTo)
        XCTAssertEqual(histories.first?.relatedDateKey, "2026-11-04")

        let habits = try context.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits.first?.name, "散歩")
        XCTAssertEqual(habits.first?.shortLabel, "歩")
        XCTAssertEqual(habits.first?.colorHex, "#00AA00")
        XCTAssertEqual(habits.first?.sortOrder, 2)
        XCTAssertEqual(habits.first?.carriedFromHabitID, previousHabitID)

        let habitEntries = try context.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(habitEntries.count, 1)
        XCTAssertEqual(habitEntries.first?.habitID, habit.id)
        XCTAssertEqual(habitEntries.first?.dateKey, "2026-11-04")
        XCTAssertEqual(habitEntries.first?.isDone, false)

        let moods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.dateKey, "2026-11-05")
        XCTAssertEqual(moods.first?.level, 1)
        XCTAssertEqual(moods.first?.note, "低い")

        let sleeps = try context.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(sleeps.first?.dateKey, "2026-11-06")
        XCTAssertEqual(sleeps.first?.hours, 6.5)
        XCTAssertEqual(sleeps.first?.quality, 2)

        let links = try context.fetch(FetchDescriptor<PageLink>())
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.fromPageID, page.id)
        XCTAssertEqual(links.first?.typeRaw, "carryOver")
        XCTAssertEqual(links.first?.type, .carryOver)
    }

    /// 一時フォルダのファイルに保存し、入れ物を手放してから、同じファイルを開き直す。
    /// アプリを閉じても残ることの確認。テスト後に一時ファイルを消す。
    func testDailyPageAndTaskRemainAfterReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("easy-journal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let storeURL = directory.appendingPathComponent("EasyJournal.store")

        try writeDailyPageForReopen(at: storeURL)

        let container = try makeFileContainer(at: storeURL)
        let context = ModelContext(container)
        let pages = try context.fetch(FetchDescriptor<DailyPage>())
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.dateKey, "2026-10-27")
        XCTAssertEqual(pages.first?.memo, "残るメモ")

        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "残るタスク")
        XCTAssertEqual(tasks.first?.daily?.dateKey, "2026-10-27")
    }

    func testDeletingDailyPageDeletesItsTaskAndKeepsIndependentRecords() throws {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let daily = DailyPage(dateKey: "2026-10-27", memo: "消える日")
        let task = JournalTask(title: "消えるタスク")
        context.insert(daily)
        context.insert(task)
        task.daily = daily

        let taskID = task.id
        let mood = MoodEntry(dateKey: "2026-10-27", level: 4, note: "残る気分")
        let sleep = SleepEntry(dateKey: "2026-10-27", hours: 7.5, quality: 3)
        let habitEntry = HabitEntry(habitID: UUID(), dateKey: "2026-10-27", isDone: true)
        let logLine = MonthlyLogLine(dateKey: "2026-10-27", text: "残る一行")
        let history = TaskHistory(taskID: taskID, actionRaw: TaskHistoryAction.created.rawValue)
        context.insert(mood)
        context.insert(sleep)
        context.insert(habitEntry)
        context.insert(logLine)
        context.insert(history)
        try context.save()

        context.delete(daily)
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertTrue(tasks.isEmpty)
        let dailies = try context.fetch(FetchDescriptor<DailyPage>())
        XCTAssertTrue(dailies.isEmpty)

        let moods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.note, "残る気分")

        let sleeps = try context.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(sleeps.first?.hours, 7.5)

        let habitEntries = try context.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(habitEntries.count, 1)

        let lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.text, "残る一行")

        let histories = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.taskID, taskID)
    }

    func testProgressRawRoundTripAndUnknownValueFallsBack() throws {
        let task = JournalTask(title: "途中")
        task.progress = .partial
        XCTAssertEqual(task.progressRaw, "partial")
        XCTAssertEqual(task.progress, .partial)

        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(task)
        try context.save()

        let loaded = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.progressRaw, "partial")
        XCTAssertEqual(loaded.first?.progress, .partial)

        loaded.first?.progressRaw = "not-a-progress"
        XCTAssertEqual(loaded.first?.progress, .open)

        let page = Page()
        page.kindRaw = "not-a-kind"
        XCTAssertEqual(page.kind, .daily)

        let history = TaskHistory()
        history.fromProgressRaw = "not-a-progress"
        XCTAssertNil(history.fromProgress)
    }

    func testSchemaVersionIsOneAndHasTwelveModels() {
        let version = EasyJournalSchemaV1.versionIdentifier
        XCTAssertEqual(version, Schema.Version(1, 0, 0))
        XCTAssertEqual(version.major, 1)
        XCTAssertEqual(version.minor, 0)
        XCTAssertEqual(version.patch, 0)
        XCTAssertEqual(EasyJournalSchemaV1.models.count, 12)
        XCTAssertTrue(schemaHas("Journal"))
        XCTAssertTrue(schemaHas("Page"))
        XCTAssertTrue(schemaHas("MonthlyPage"))
        XCTAssertTrue(schemaHas("MonthlyLogLine"))
        XCTAssertTrue(schemaHas("DailyPage"))
        XCTAssertTrue(schemaHas("JournalTask"))
        XCTAssertTrue(schemaHas("TaskHistory"))
        XCTAssertTrue(schemaHas("Habit"))
        XCTAssertTrue(schemaHas("HabitEntry"))
        XCTAssertTrue(schemaHas("MoodEntry"))
        XCTAssertTrue(schemaHas("SleepEntry"))
        XCTAssertTrue(schemaHas("PageLink"))

        XCTAssertEqual(EasyJournalMigrationPlan.schemas.count, 1)
        XCTAssertTrue(EasyJournalMigrationPlan.stages.isEmpty)
    }

    /// 検索条件（`#Predicate`）で、dateKey が一致する日ページだけ取る。
    func testPredicateFindsDailyPageByDateKey() throws {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let targetKey = "2026-10-27"
        context.insert(DailyPage(dateKey: targetKey, memo: "一致する日"))
        context.insert(DailyPage(dateKey: "2026-10-28", memo: "別の日"))
        try context.save()

        let descriptor = FetchDescriptor<DailyPage>(
            predicate: #Predicate { page in
                page.dateKey == targetKey
            }
        )
        let found = try context.fetch(descriptor)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.dateKey, targetKey)
        XCTAssertEqual(found.first?.memo, "一致する日")
    }

    /// 検索条件（`#Predicate`）で、進み具合の文字列が `partial` のタスクだけ取る。
    func testPredicateFindsTaskByProgressRaw() throws {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let partialRaw = TaskProgress.partial.rawValue
        context.insert(JournalTask(title: "途中", progressRaw: partialRaw))
        context.insert(JournalTask(title: "未完", progressRaw: TaskProgress.open.rawValue))
        try context.save()

        let descriptor = FetchDescriptor<JournalTask>(
            predicate: #Predicate { task in
                task.progressRaw == partialRaw
            }
        )
        let found = try context.fetch(descriptor)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.title, "途中")
        XCTAssertEqual(found.first?.progress, .partial)
    }

    /// スキーマに、その名前のモデルがあるか。
    /// モジュール名が付いていても、付いていなくても一致とみなす。
    private func schemaHas(_ name: String) -> Bool {
        EasyJournalSchemaV1.models.contains { model in
            let description = String(describing: model)
            return description == name || description.hasSuffix(".\(name)")
        }
    }

    /// ファイルの保存先。公式の `ModelConfiguration.init(_:schema:url:allowsSave:cloudKitDatabase:)`（iOS 17 以上）。
    /// 同期は使わない（`.none`）。App Group は使わない。
    private func makeFileContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: EasyJournalSchemaV1.self)
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: EasyJournalMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// 入れ物をこの関数の中だけで使い、戻ったあとに手放す。
    /// 同じファイルを、このあと開き直す。
    private func writeDailyPageForReopen(at storeURL: URL) throws {
        try autoreleasepool {
            var container: ModelContainer? = try makeFileContainer(at: storeURL)
            var context: ModelContext? = container.map { ModelContext($0) }
            let daily = DailyPage(dateKey: "2026-10-27", memo: "残るメモ")
            let task = JournalTask(title: "残るタスク")
            context?.insert(daily)
            context?.insert(task)
            task.daily = daily
            try context?.save()
            context = nil
            container = nil
        }
    }
}
