import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// 月のタスク。進み具合、履歴、追加、削除、一覧。メモリ上の保存だけ。
final class MonthlyTaskTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    /// □ → ◧ → ■ → □。`nextProgress` の3遷移。
    func testNextProgressThreeTransitions() {
        struct Row {
            let from: TaskProgress
            let to: TaskProgress
        }
        let rows = [
            Row(from: .open, to: .partial),
            Row(from: .partial, to: .done),
            Row(from: .done, to: .open),
        ]
        XCTAssertEqual(rows.count, 3)
        for row in rows {
            XCTAssertEqual(
                TaskRules.nextProgress(row.from),
                row.to,
                row.from.rawValue
            )
        }
    }

    /// 月のタスクを1回進めるたびに、履歴が from / to つきで1件増える。
    /// 完了のときだけ completedAt が入る。□ に戻すと nil。
    func testCycleProgressAppendsOneHistoryPerChangeWithFromToAndCompletedAt() throws {
        struct Step {
            let from: TaskProgress
            let to: TaskProgress
            let setsCompletedAt: Bool
        }
        let steps = [
            Step(from: .open, to: .partial, setsCompletedAt: false),
            Step(from: .partial, to: .done, setsCompletedAt: true),
            Step(from: .done, to: .open, setsCompletedAt: false),
        ]
        var stamps: [Date] = []
        let origin = Date(timeIntervalSince1970: 1_800_000_000)
        let (store, context, _) = try makeStore(now: {
            let instant = Date(timeIntervalSince1970: origin.timeIntervalSince1970 + Double(stamps.count))
            stamps.append(instant)
            return instant
        })

        let task = try store.addMonthlyTask(monthKey: "2026-10", title: "進める")
        XCTAssertEqual(task.scope, .monthly)
        XCTAssertEqual(task.progress, .open)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(stamps.count, 1)
        if stamps.count == 1 {
            XCTAssertEqual(task.createdAt, stamps[0])
        }

        var seenIDs: [UUID] = []
        let created = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created.first?.action, .created)
        XCTAssertNil(created.first?.fromProgress)
        XCTAssertEqual(created.first?.toProgress, .open)
        if let createdID = created.first?.id {
            seenIDs.append(createdID)
        }

        for step in steps {
            let before = try context.fetch(FetchDescriptor<TaskHistory>())
            let result = try store.cycleProgress(taskID: task.id)
            XCTAssertEqual(result, step.to, step.from.rawValue)
            XCTAssertEqual(task.progress, step.to, step.from.rawValue)
            if step.setsCompletedAt {
                XCTAssertEqual(stamps.count, 3)
                if stamps.count == 3 {
                    XCTAssertEqual(task.completedAt, stamps[2])
                }
            } else {
                XCTAssertNil(task.completedAt, step.from.rawValue)
            }

            let after = try context.fetch(FetchDescriptor<TaskHistory>())
            XCTAssertEqual(after.count, before.count + 1, step.from.rawValue)
            let added = after.filter { item in
                seenIDs.contains(item.id) == false
            }
            XCTAssertEqual(added.count, 1, step.from.rawValue)
            XCTAssertEqual(added.first?.action, .progressChanged, step.from.rawValue)
            XCTAssertEqual(added.first?.fromProgress, step.from, step.from.rawValue)
            XCTAssertEqual(added.first?.toProgress, step.to, step.from.rawValue)
            XCTAssertEqual(added.first?.fromProgressRaw, step.from.rawValue, step.from.rawValue)
            XCTAssertEqual(added.first?.toProgressRaw, step.to.rawValue, step.from.rawValue)
            if let newID = added.first?.id {
                seenIDs.append(newID)
            }
            for oldID in seenIDs.dropLast() {
                let matches = after.filter { item in
                    item.id == oldID
                }
                XCTAssertEqual(matches.count, 1, oldID.uuidString)
            }
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 4)
    }

    /// 空白だけのタイトルは足さない。履歴もページも作らない。前後の空白は削って保存する。
    func testAddMonthlyTaskRejectsBlankTitle() throws {
        let blanks = ["", " ", "   ", "\n", "\t", " \n\t ", "　", " \u{3000} "]
        let (store, context, _) = try makeStore()
        for title in blanks {
            XCTAssertThrowsError(try store.addMonthlyTask(monthKey: "2026-10", title: title)) { error in
                XCTAssertEqual(error as? JournalStoreError, .emptyTitle, title)
            }
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)

        let added = try store.addMonthlyTask(monthKey: "2026-10", title: "  年賀状  ")
        XCTAssertEqual(added.title, "年賀状")
        XCTAssertEqual(added.scope, .monthly)
        XCTAssertEqual(added.progress, .open)
        XCTAssertNil(added.completedAt)
        let histories = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.action, .created)
        XCTAssertNil(histories.first?.fromProgress)
        XCTAssertEqual(histories.first?.toProgress, .open)

        let before = try context.fetchCount(FetchDescriptor<TaskHistory>())
        XCTAssertThrowsError(try store.addMonthlyTask(monthKey: "2026-10", title: " \n ")) { error in
            XCTAssertEqual(error as? JournalStoreError, .emptyTitle)
        }
        XCTAssertEqual(try store.monthlyTasks(monthKey: "2026-10").map { task in task.id }, [added.id])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), before)
    }

    /// 消すのはその1件だけ。同じ月の他のタスクと、別の月のタスクと、日のタスクは残る。
    func testDeleteMonthlyTaskLeavesSameMonthAndOtherMonth() throws {
        let (store, context, _) = try makeStore()
        let keep = try store.addMonthlyTask(monthKey: "2026-10", title: "残す")
        let remove = try store.addMonthlyTask(monthKey: "2026-10", title: "消す")
        let otherMonth = try store.addMonthlyTask(monthKey: "2026-11", title: "別の月")
        let daily = try store.addDailyTask(dateKey: "2026-10-03", title: "日のタスク")

        let before = try store.monthlyTasks(monthKey: "2026-10")
        XCTAssertEqual(before.map { task in task.title }, ["残す", "消す"])
        XCTAssertFalse(before.contains { task in task.id == otherMonth.id })
        XCTAssertFalse(before.contains { task in task.id == daily.id })

        try store.deleteTask(taskID: remove.id)

        let october = try store.monthlyTasks(monthKey: "2026-10")
        XCTAssertEqual(october.map { task in task.id }, [keep.id])
        XCTAssertEqual(october.map { task in task.title }, ["残す"])
        let november = try store.monthlyTasks(monthKey: "2026-11")
        XCTAssertEqual(november.map { task in task.id }, [otherMonth.id])
        XCTAssertEqual(november.map { task in task.title }, ["別の月"])

        let stored = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertTrue(stored.contains { task in task.id == daily.id })
        XCTAssertTrue(stored.contains { task in task.id == keep.id })
        XCTAssertTrue(stored.contains { task in task.id == otherMonth.id })
        XCTAssertFalse(stored.contains { task in task.id == remove.id })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)
    }

    /// 一覧は sortOrder、同じなら作った時刻。別の月と、日のタスクは混ざらない。
    func testMonthlyTaskListSortsAndOmitsOtherMonthsAndDailyScope() throws {
        let (store, context, _) = try makeStore()
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let october = try store.findOrCreateMonthly(monthKey: "2026-10")
        let november = try store.findOrCreateMonthly(monthKey: "2026-11")

        let orderZero = makeTask(title: "並び0", sortOrder: 0, createdAt: late)
        let tieEarly = makeTask(title: "同じ順で早い", sortOrder: 1, createdAt: early)
        let tieLate = makeTask(title: "同じ順で遅い", sortOrder: 1, createdAt: late)
        let orderTwo = makeTask(title: "並び2", sortOrder: 2, createdAt: early)
        let dailyOnMonth = makeTask(
            title: "日のタスク",
            scopeRaw: TaskScope.daily.rawValue,
            sortOrder: 0,
            createdAt: early
        )
        let otherMonth = makeTask(title: "別の月", sortOrder: 0, createdAt: early)

        for task in [orderZero, tieEarly, tieLate, orderTwo, dailyOnMonth] {
            context.insert(task)
            task.monthly = october
        }
        context.insert(otherMonth)
        otherMonth.monthly = november
        try context.save()

        let titles = try store.monthlyTasks(monthKey: "2026-10").map { task in task.title }
        XCTAssertEqual(titles, ["並び0", "同じ順で早い", "同じ順で遅い", "並び2"])
        XCTAssertFalse(titles.contains("日のタスク"))
        XCTAssertFalse(titles.contains("別の月"))
        XCTAssertEqual(
            try store.monthlyTasks(monthKey: "2026-11").map { task in task.title },
            ["別の月"]
        )
    }

    /// 月が無い、または月キーが不正なら、空。ページは作らない。
    func testMonthlyTasksOnMissingMonthDoesNotCreate() throws {
        let (store, context, _) = try makeStore()
        XCTAssertTrue(try store.monthlyTasks(monthKey: "2026-10").isEmpty)
        XCTAssertTrue(try store.monthlyTasks(monthKey: "2026-13").isEmpty)
        XCTAssertTrue(try store.monthlyTasks(monthKey: "").isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 0)
    }

    /// 記号と読み上げ。完了かつ繰越済みでも落ちない。
    func testMonthlyTaskSymbolAndSpokenProgress() {
        struct Row {
            let progress: TaskProgress
            let symbol: String
            let spoken: String
        }
        let rows = [
            Row(progress: .open, symbol: "□", spoken: "未完"),
            Row(progress: .partial, symbol: "◧", spoken: "一部"),
            Row(progress: .done, symbol: "■", spoken: "完了"),
        ]
        for row in rows {
            let task = JournalTask(
                title: "読む",
                scopeRaw: TaskScope.monthly.rawValue,
                progressRaw: row.progress.rawValue
            )
            let item = MonthlyTaskItem(task: task)
            XCTAssertEqual(item.symbol, row.symbol, row.progress.rawValue)
            XCTAssertEqual(item.spokenProgress, row.spoken, row.progress.rawValue)
            XCTAssertEqual(MonthlyTaskItem.symbol(for: row.progress), row.symbol, row.progress.rawValue)
            XCTAssertEqual(
                MonthlyTaskItem.spokenProgress(for: row.progress),
                row.spoken,
                row.progress.rawValue
            )
        }

        let invalid = JournalTask(
            title: "例外",
            scopeRaw: TaskScope.monthly.rawValue,
            progressRaw: TaskProgress.done.rawValue,
            isCarriedForward: true
        )
        let shown = MonthlyTaskItem(task: invalid)
        XCTAssertEqual(shown.symbol, "■")
        XCTAssertEqual(shown.spokenProgress, "完了")
    }

    // MARK: - ヘルパー

    private func makeStore(
        now: (() -> Date)? = nil
    ) throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let clock: () -> Date
        if let provided = now {
            clock = provided
        } else {
            let instant = fixedNow
            clock = { instant }
        }
        let store = JournalStore(context: context, now: clock)
        return (store, context, container)
    }

    private func makeTask(
        title: String,
        scopeRaw: String = TaskScope.monthly.rawValue,
        sortOrder: Int,
        createdAt: Date
    ) -> JournalTask {
        JournalTask(
            title: title,
            scopeRaw: scopeRaw,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: nil,
            carriedToTaskID: nil,
            sortOrder: sortOrder,
            createdAt: createdAt,
            completedAt: nil
        )
    }
}
