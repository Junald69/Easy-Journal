import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// タスクの追加、名前の変更、削除、進み具合。メモリ上の保存だけ。
final class JournalStoreTasksTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    /// 日のタスクを作る。前後の空白は削る。日ページと「作った」履歴が1件できる。
    func testAddDailyTaskTrimsTitleCreatesDailyAndHistory() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "  牛乳  を買う  ")

        XCTAssertEqual(task.title, "牛乳  を買う")
        XCTAssertEqual(task.scope, .daily)
        XCTAssertEqual(task.scopeRaw, TaskScope.daily.rawValue)
        XCTAssertEqual(task.progress, .open)
        XCTAssertEqual(task.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(task.sortOrder, 0)
        XCTAssertFalse(task.isCarriedForward)
        XCTAssertNil(task.completedAt)
        XCTAssertNil(task.carriedFromTaskID)
        XCTAssertNil(task.carriedToTaskID)
        XCTAssertEqual(task.createdAt, fixedNow)
        XCTAssertEqual(task.daily?.dateKey, "2026-10-27")
        XCTAssertEqual(task.daily?.page?.createdBy, .user)
        XCTAssertNil(task.monthly)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 1)

        let histories = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.taskID, task.id)
        XCTAssertEqual(histories.first?.action, .created)
        XCTAssertEqual(histories.first?.actionRaw, TaskHistoryAction.created.rawValue)
        XCTAssertNil(histories.first?.fromProgress)
        XCTAssertEqual(histories.first?.toProgress, .open)
        XCTAssertEqual(histories.first?.at, fixedNow)
        XCTAssertNil(histories.first?.relatedTaskID)
        XCTAssertNil(histories.first?.relatedDateKey)

        let carried = try store.addDailyTask(
            dateKey: "2026-11-02",
            title: "自動",
            createdBy: .carryOver
        )
        XCTAssertEqual(carried.daily?.page?.createdBy, .carryOver)
        XCTAssertEqual(carried.daily?.page?.createdByRaw, PageCreatedBy.carryOver.rawValue)
        XCTAssertEqual(carried.sortOrder, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
    }

    /// 並びは 0、1、2 と増える。飛び番の最大 + 1。別の日は 0 から。月のタスクの並びは混ぜない。
    func testAddDailyTaskSortOrderIncreases() throws {
        let (store, context, _) = try makeStore()
        let first = try store.addDailyTask(dateKey: "2026-10-27", title: "いち")
        let second = try store.addDailyTask(dateKey: "2026-10-27", title: "に")
        let third = try store.addDailyTask(dateKey: "2026-10-27", title: "さん")
        XCTAssertEqual(first.sortOrder, 0)
        XCTAssertEqual(second.sortOrder, 1)
        XCTAssertEqual(third.sortOrder, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)

        guard let daily = first.daily else {
            XCTFail("日ページがありません")
            return
        }
        let gap = JournalTask(title: "すきま", sortOrder: 10)
        context.insert(gap)
        gap.daily = daily
        try context.save()

        let afterGap = try store.addDailyTask(dateKey: "2026-10-27", title: "すきまの次")
        XCTAssertEqual(afterGap.sortOrder, 11)

        let otherDay = try store.addDailyTask(dateKey: "2026-10-28", title: "別の日")
        XCTAssertEqual(otherDay.sortOrder, 0)

        let monthly = try store.addMonthlyTask(monthKey: "2026-10", title: "月")
        guard let monthlyPage = monthly.monthly else {
            XCTFail("月ページがありません")
            return
        }
        let highMonthly = JournalTask(
            title: "月の大きい並び",
            scopeRaw: TaskScope.monthly.rawValue,
            sortOrder: 50
        )
        context.insert(highMonthly)
        highMonthly.monthly = monthlyPage
        try context.save()

        let stillDaily = try store.addDailyTask(dateKey: "2026-10-29", title: "日は別")
        XCTAssertEqual(stillDaily.sortOrder, 0)
    }

    /// 空の名前、不正な日付では、何も作らない。日付が不正なら、空の名前より先に日付のエラー。
    func testAddDailyTaskEmptyTitleAndInvalidDateCreateNothing() throws {
        let (store, context, _) = try makeStore()
        XCTAssertThrowsError(try store.addDailyTask(dateKey: "2026-10-27", title: " \n\t ")) { error in
            XCTAssertEqual(error as? JournalStoreError, .emptyTitle)
        }
        XCTAssertThrowsError(try store.addDailyTask(dateKey: "2026-02-30", title: "ある")) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey("2026-02-30"))
        }
        XCTAssertThrowsError(try store.addDailyTask(dateKey: "2026-02-30", title: " ")) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey("2026-02-30"))
        }
        try assertNoStoredRecords(in: context)
    }

    /// 月のタスクは monthly。名前の空白は削る。並びは 0 から。日のタスクの並びとは別。
    func testAddMonthlyTaskUsesMonthlyScope() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addMonthlyTask(monthKey: "2026-10", title: "  月の目標  ")
        XCTAssertEqual(task.title, "月の目標")
        XCTAssertEqual(task.scope, .monthly)
        XCTAssertEqual(task.scopeRaw, TaskScope.monthly.rawValue)
        XCTAssertEqual(task.progress, .open)
        XCTAssertEqual(task.sortOrder, 0)
        XCTAssertNil(task.daily)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(task.createdAt, fixedNow)
        XCTAssertEqual(task.monthly?.monthKey, "2026-10")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 1)

        let histories = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.taskID, task.id)
        XCTAssertEqual(histories.first?.action, .created)
        XCTAssertEqual(histories.first?.toProgress, .open)
        XCTAssertNil(histories.first?.fromProgress)

        let second = try store.addMonthlyTask(monthKey: "2026-10", title: "ふたつ目")
        XCTAssertEqual(second.sortOrder, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)

        let daily = try store.addDailyTask(dateKey: "2026-10-03", title: "日")
        guard let dailyPage = daily.daily else {
            XCTFail("日ページがありません")
            return
        }
        let highDaily = JournalTask(title: "日の大きい並び", sortOrder: 40)
        context.insert(highDaily)
        highDaily.daily = dailyPage
        try context.save()

        let third = try store.addMonthlyTask(monthKey: "2026-10", title: "三つ目")
        XCTAssertEqual(third.sortOrder, 2)
        XCTAssertNil(third.daily)
        XCTAssertEqual(third.scope, .monthly)
    }

    /// 空の名前、不正な月では、何も作らない。月が不正なら、空の名前より先に月のエラー。
    func testAddMonthlyTaskEmptyTitleAndInvalidMonthCreateNothing() throws {
        let (store, context, _) = try makeStore()
        XCTAssertThrowsError(try store.addMonthlyTask(monthKey: "2026-10", title: " \n ")) { error in
            XCTAssertEqual(error as? JournalStoreError, .emptyTitle)
        }
        XCTAssertThrowsError(try store.addMonthlyTask(monthKey: "2026-13", title: "ある")) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidMonthKey("2026-13"))
        }
        XCTAssertThrowsError(try store.addMonthlyTask(monthKey: "", title: "")) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidMonthKey(""))
        }
        try assertNoStoredRecords(in: context)
    }

    /// 名前を変えると、edited の履歴が1件増える。前後の空白は削って保存する。
    func testEditTaskTitleAppendsEditedHistory() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "元")
        try store.editTaskTitle(taskID: task.id, title: "  新しい名前  ")

        XCTAssertEqual(task.title, "新しい名前")
        let histories = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 2)
        let edited = histories.filter { item in
            item.actionRaw == TaskHistoryAction.edited.rawValue
        }
        let created = histories.filter { item in
            item.actionRaw == TaskHistoryAction.created.rawValue
        }
        XCTAssertEqual(edited.count, 1)
        XCTAssertEqual(edited.first?.taskID, task.id)
        XCTAssertEqual(edited.first?.action, .edited)
        XCTAssertNil(edited.first?.fromProgressRaw)
        XCTAssertNil(edited.first?.toProgressRaw)
        XCTAssertEqual(edited.first?.at, fixedNow)
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created.first?.actionRaw, TaskHistoryAction.created.rawValue)
    }

    /// 削ったあと同じ名前なら、履歴は増えない。
    func testEditTaskTitleSameTitleDoesNotAppendHistory() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "  同じ  ")
        XCTAssertEqual(task.title, "同じ")
        let before = try context.fetchCount(FetchDescriptor<TaskHistory>())

        try store.editTaskTitle(taskID: task.id, title: "同じ")
        try store.editTaskTitle(taskID: task.id, title: "  同じ \n")

        XCTAssertEqual(task.title, "同じ")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), before)
        XCTAssertEqual(before, 1)
    }

    /// 空の名前はエラーで、今の名前と履歴は残る。無い ID もエラー。
    func testEditTaskTitleEmptyAndMissingThrow() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "残る")
        let before = try context.fetchCount(FetchDescriptor<TaskHistory>())

        XCTAssertThrowsError(try store.editTaskTitle(taskID: task.id, title: " \n ")) { error in
            XCTAssertEqual(error as? JournalStoreError, .emptyTitle)
        }
        XCTAssertEqual(task.title, "残る")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), before)

        let missing = UUID()
        XCTAssertThrowsError(try store.editTaskTitle(taskID: missing, title: "何か")) { error in
            XCTAssertEqual(error as? JournalStoreError, .taskNotFound(missing))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), before)
    }

    /// 消しても「作った」履歴は残り、「消した」履歴が足される。タスクは消え、日ページは残る。
    func testDeleteTaskKeepsHistoryAndRemovesTask() throws {
        let (store, _, container) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "消す")
        let removedID = task.id
        guard let dailyID = task.daily?.id else {
            XCTFail("日ページがありません")
            return
        }
        try store.deleteTask(taskID: removedID)

        let other = ModelContext(container)
        XCTAssertTrue(try other.fetch(FetchDescriptor<JournalTask>()).isEmpty)
        let dailies = try other.fetch(FetchDescriptor<DailyPage>())
        XCTAssertEqual(dailies.count, 1)
        XCTAssertEqual(dailies.first?.id, dailyID)

        let histories = try other.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 2)
        let created = histories.filter { item in
            item.actionRaw == TaskHistoryAction.created.rawValue
        }
        let deleted = histories.filter { item in
            item.actionRaw == TaskHistoryAction.deleted.rawValue
        }
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created.first?.taskID, removedID)
        XCTAssertEqual(deleted.count, 1)
        XCTAssertEqual(deleted.first?.taskID, removedID)
        XCTAssertEqual(deleted.first?.action, .deleted)
        XCTAssertEqual(deleted.first?.fromProgress, .open)
        XCTAssertEqual(deleted.first?.fromProgressRaw, TaskProgress.open.rawValue)
        XCTAssertNil(deleted.first?.toProgressRaw)
    }

    /// 消すタスクの繰越元・繰越先は、相手側の ID だけ空になる。繰越済みの印と、相手の履歴は変えない。
    func testDeleteTaskClearsPartnerIDs() throws {
        guard let sourceID = uuid("00000000-0000-0000-0000-000000000021"),
              let middleID = uuid("00000000-0000-0000-0000-000000000022"),
              let destinationID = uuid("00000000-0000-0000-0000-000000000023") else {
            return
        }
        let (store, context, container) = try makeStore()
        let source = JournalTask(
            id: sourceID,
            title: "元",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: true,
            carriedFromTaskID: nil,
            carriedToTaskID: middleID,
            sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 1_000),
            completedAt: nil
        )
        let middle = JournalTask(
            id: middleID,
            title: "中",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.partial.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: sourceID,
            carriedToTaskID: destinationID,
            sortOrder: 1,
            createdAt: Date(timeIntervalSince1970: 2_000),
            completedAt: nil
        )
        let destination = JournalTask(
            id: destinationID,
            title: "先",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: true,
            carriedFromTaskID: middleID,
            carriedToTaskID: nil,
            sortOrder: 2,
            createdAt: Date(timeIntervalSince1970: 3_000),
            completedAt: nil
        )
        context.insert(source)
        context.insert(middle)
        context.insert(destination)
        try context.save()

        try store.deleteTask(taskID: middleID)

        let other = ModelContext(container)
        let tasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 2)
        let storedSource = tasks.first { item in
            item.id == sourceID
        }
        let storedDestination = tasks.first { item in
            item.id == destinationID
        }
        XCTAssertNil(tasks.first { item in
            item.id == middleID
        })
        XCTAssertEqual(storedSource?.carriedToTaskID, nil)
        XCTAssertEqual(storedSource?.isCarriedForward, true)
        XCTAssertEqual(storedSource?.title, "元")
        XCTAssertEqual(storedDestination?.carriedFromTaskID, nil)
        XCTAssertEqual(storedDestination?.isCarriedForward, true)
        XCTAssertEqual(storedDestination?.title, "先")

        let histories = try other.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.taskID, middleID)
        XCTAssertEqual(histories.first?.actionRaw, TaskHistoryAction.deleted.rawValue)
        XCTAssertEqual(histories.first?.fromProgressRaw, TaskProgress.partial.rawValue)
        XCTAssertNil(histories.first?.toProgressRaw)
    }

    /// 無い ID を消そうとするとエラー。何も作らない。
    func testDeleteTaskMissingThrows() throws {
        let (store, context, _) = try makeStore()
        let missing = UUID()
        XCTAssertThrowsError(try store.deleteTask(taskID: missing)) { error in
            XCTAssertEqual(error as? JournalStoreError, .taskNotFound(missing))
        }
        try assertNoStoredRecords(in: context)
    }

    /// open → partial → done → open。履歴は進み具合の変化が3件。完了のときだけ完了時刻が入る。
    func testCycleProgressRotatesOpenPartialDoneOpen() throws {
        var stamps: [Date] = []
        let origin = Date(timeIntervalSince1970: 1_900_000_000)
        let (store, context, _) = try makeStore(now: {
            let instant = Date(
                timeIntervalSince1970: origin.timeIntervalSince1970 + Double(stamps.count)
            )
            stamps.append(instant)
            return instant
        })

        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "進める")
        XCTAssertEqual(stamps.count, 1)
        XCTAssertEqual(task.progress, .open)
        XCTAssertNil(task.completedAt)
        if stamps.count == 1 {
            XCTAssertEqual(task.createdAt, stamps[0])
        }

        let partial = try store.cycleProgress(taskID: task.id)
        XCTAssertEqual(partial, .partial)
        XCTAssertEqual(task.progressRaw, TaskProgress.partial.rawValue)
        XCTAssertNil(task.completedAt)

        let done = try store.cycleProgress(taskID: task.id)
        XCTAssertEqual(done, .done)
        XCTAssertEqual(task.progress, .done)
        XCTAssertEqual(stamps.count, 3)
        if stamps.count == 3 {
            XCTAssertEqual(task.completedAt, stamps[2])
        }

        let opened = try store.cycleProgress(taskID: task.id)
        XCTAssertEqual(opened, .open)
        XCTAssertEqual(task.progressRaw, TaskProgress.open.rawValue)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(stamps.count, 4)

        let histories = try context.fetch(FetchDescriptor<TaskHistory>())
        let progressOnes = histories.filter { item in
            item.actionRaw == TaskHistoryAction.progressChanged.rawValue
        }
        XCTAssertEqual(histories.count, 4)
        XCTAssertEqual(progressOnes.count, 3)
        let ordered = progressOnes.sorted { lhs, rhs in
            if lhs.at != rhs.at {
                return lhs.at < rhs.at
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        XCTAssertEqual(ordered.first?.fromProgress, .open)
        XCTAssertEqual(ordered.first?.toProgress, .partial)
        XCTAssertEqual(ordered.dropFirst(1).first?.fromProgress, .partial)
        XCTAssertEqual(ordered.dropFirst(1).first?.toProgress, .done)
        XCTAssertEqual(ordered.dropFirst(2).first?.fromProgress, .done)
        XCTAssertEqual(ordered.dropFirst(2).first?.toProgress, .open)
    }

    /// 繰越済みは、進み具合も履歴も変わらない。
    func testCycleProgressCarriedForwardDoesNotChange() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "送った")
        task.isCarriedForward = true
        try context.save()
        let before = try context.fetchCount(FetchDescriptor<TaskHistory>())

        let result = try store.cycleProgress(taskID: task.id)
        XCTAssertEqual(result, .open)
        XCTAssertEqual(task.progress, .open)
        XCTAssertEqual(task.progressRaw, TaskProgress.open.rawValue)
        XCTAssertTrue(task.isCarriedForward)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), before)
    }

    /// 無い ID の進み具合はエラー。何も作らない。
    func testCycleProgressMissingThrows() throws {
        let (store, context, _) = try makeStore()
        let missing = UUID()
        XCTAssertThrowsError(try store.cycleProgress(taskID: missing)) { error in
            XCTAssertEqual(error as? JournalStoreError, .taskNotFound(missing))
        }
        try assertNoStoredRecords(in: context)
    }

    /// あとから操作しても、すでにある履歴の id と actionRaw と時刻は変わらない。
    func testTaskHistoryIsAppendOnly() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "履歴")
        _ = try store.cycleProgress(taskID: task.id)
        try store.editTaskTitle(taskID: task.id, title: "一度目")

        let before = try context.fetch(FetchDescriptor<TaskHistory>())
        let snapshot = before.map { item in
            (item.id, item.actionRaw, item.at)
        }
        XCTAssertEqual(snapshot.count, 3)

        _ = try store.cycleProgress(taskID: task.id)
        try store.editTaskTitle(taskID: task.id, title: "二度目")

        let after = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(after.count, snapshot.count + 2)
        for stamp in snapshot {
            let (stampID, actionRaw, stampAt) = stamp
            let matches = after.filter { item in
                item.id == stampID
            }
            XCTAssertEqual(matches.count, 1)
            XCTAssertEqual(matches.first?.actionRaw, actionRaw)
            XCTAssertEqual(matches.first?.at, stampAt)
        }
    }

    /// 別の読み書き窓口から、タスクと「作った」履歴が見える。
    func testSavedTaskIsVisibleFromAnotherContext() throws {
        let (store, _, container) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "残るタスク")
        let taskID = task.id

        let other = ModelContext(container)
        let tasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, taskID)
        XCTAssertEqual(tasks.first?.title, "残るタスク")
        XCTAssertEqual(tasks.first?.scopeRaw, TaskScope.daily.rawValue)
        XCTAssertEqual(tasks.first?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(tasks.first?.sortOrder, 0)
        XCTAssertEqual(tasks.first?.daily?.dateKey, "2026-10-27")

        let histories = try other.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.taskID, taskID)
        XCTAssertEqual(histories.first?.actionRaw, TaskHistoryAction.created.rawValue)
        XCTAssertEqual(histories.first?.toProgressRaw, TaskProgress.open.rawValue)
    }

    /// 保存が失敗したら、削除は取り消される。履歴の件数も、別の窓口から見た中身も変わらない。
    func testDeleteTaskRollsBackWhenSaveThrows() throws {
        let flag = ThrowSwitch()
        let (store, context, container) = try makeThrowingStore(shouldThrow: { flag.isOn })
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "残る")
        let taskID = task.id
        let historyBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(historyBefore, 1)
        flag.isOn = true

        XCTAssertThrowsError(try store.deleteTask(taskID: taskID)) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }
        XCTAssertFalse(context.hasChanges)
        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, taskID)
        XCTAssertEqual(tasks.first?.title, "残る")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)

        let other = ModelContext(container)
        let otherTasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(otherTasks.count, 1)
        XCTAssertEqual(otherTasks.first?.id, taskID)
        XCTAssertEqual(otherTasks.first?.title, "残る")
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)
    }

    /// 保存が失敗したら、日のタスク追加は取り消される。ページも履歴も残らない。
    func testAddDailyTaskRollsBackWhenSaveThrows() throws {
        let flag = ThrowSwitch()
        flag.isOn = true
        let (store, context, container) = try makeThrowingStore(shouldThrow: { flag.isOn })

        XCTAssertThrowsError(try store.addDailyTask(dateKey: "2026-10-27", title: "作られない")) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0)

        let other = ModelContext(container)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<JournalTask>()), 0)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<TaskHistory>()), 0)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<Page>()), 0)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<Journal>()), 0)
    }

    /// 保存が失敗したら、進み具合の変更は取り消される。履歴は増えない。
    func testCycleProgressRollsBackWhenSaveThrows() throws {
        let flag = ThrowSwitch()
        let (store, context, container) = try makeThrowingStore(shouldThrow: { flag.isOn })
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "進まない")
        let taskID = task.id
        let historyBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(historyBefore, 1)
        flag.isOn = true

        XCTAssertThrowsError(try store.cycleProgress(taskID: taskID)) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }
        XCTAssertFalse(context.hasChanges)
        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, taskID)
        XCTAssertEqual(tasks.first?.progress, .open)
        XCTAssertEqual(tasks.first?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertNil(tasks.first?.completedAt)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)

        let other = ModelContext(container)
        let otherTasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(otherTasks.first?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertNil(otherTasks.first?.completedAt)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)
    }

    /// 2件のうち1件を消しても、もう1件は残る。月のタスクを消しても、日のタスクと月ページは残る。
    func testDeletingOneTaskLeavesTheOther() throws {
        let (store, context, container) = try makeStore()
        let keep = try store.addDailyTask(dateKey: "2026-10-27", title: "残す")
        let remove = try store.addDailyTask(dateKey: "2026-10-27", title: "消す")
        let keepID = keep.id
        let removeID = remove.id
        try store.deleteTask(taskID: removeID)

        var tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, keepID)
        XCTAssertEqual(tasks.first?.title, "残す")
        XCTAssertNil(tasks.first { item in
            item.id == removeID
        })

        let monthly = try store.addMonthlyTask(monthKey: "2026-10", title: "月を消す")
        let monthlyID = monthly.id
        try store.deleteTask(taskID: monthlyID)

        tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, keepID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)

        let other = ModelContext(container)
        let otherTasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(otherTasks.count, 1)
        XCTAssertEqual(otherTasks.first?.id, keepID)
        let deleted = try other.fetch(FetchDescriptor<TaskHistory>()).filter { item in
            item.actionRaw == TaskHistoryAction.deleted.rawValue
        }
        XCTAssertEqual(deleted.count, 2)
        XCTAssertTrue(deleted.contains { item in
            item.taskID == removeID
        })
        XCTAssertTrue(deleted.contains { item in
            item.taskID == monthlyID
        })
    }

    /// 相手が無い、または相手が別のタスクを指しているときは、その ID を空にしない。
    func testDeleteTaskIgnoresMissingOrUnrelatedPartners() throws {
        guard let sourceID = uuid("00000000-0000-0000-0000-000000000031"),
              let removedID = uuid("00000000-0000-0000-0000-000000000032"),
              let followerID = uuid("00000000-0000-0000-0000-000000000033"),
              let keeperID = uuid("00000000-0000-0000-0000-000000000034") else {
            return
        }
        let (store, context, container) = try makeStore()
        let missingFrom = UUID()
        let missingTo = UUID()
        let orphan = JournalTask(
            title: "相手なし",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: missingFrom,
            carriedToTaskID: missingTo,
            sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 1_000),
            completedAt: nil
        )
        context.insert(orphan)
        try context.save()
        let orphanID = orphan.id
        try store.deleteTask(taskID: orphanID)
        XCTAssertTrue(try context.fetch(FetchDescriptor<JournalTask>()).isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 1)

        let source = JournalTask(
            id: sourceID,
            title: "元",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: true,
            carriedFromTaskID: nil,
            carriedToTaskID: keeperID,
            sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 2_000),
            completedAt: nil
        )
        let removed = JournalTask(
            id: removedID,
            title: "消す",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.partial.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: sourceID,
            carriedToTaskID: followerID,
            sortOrder: 1,
            createdAt: Date(timeIntervalSince1970: 3_000),
            completedAt: nil
        )
        let follower = JournalTask(
            id: followerID,
            title: "先",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: true,
            carriedFromTaskID: keeperID,
            carriedToTaskID: nil,
            sortOrder: 2,
            createdAt: Date(timeIntervalSince1970: 4_000),
            completedAt: nil
        )
        let keeper = JournalTask(
            id: keeperID,
            title: "別",
            scopeRaw: TaskScope.monthly.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: nil,
            carriedToTaskID: sourceID,
            sortOrder: 3,
            createdAt: Date(timeIntervalSince1970: 5_000),
            completedAt: nil
        )
        context.insert(source)
        context.insert(removed)
        context.insert(follower)
        context.insert(keeper)
        try context.save()

        try store.deleteTask(taskID: removedID)

        let other = ModelContext(container)
        let tasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertNil(tasks.first { item in
            item.id == removedID
        })
        let storedSource = tasks.first { item in
            item.id == sourceID
        }
        let storedFollower = tasks.first { item in
            item.id == followerID
        }
        let storedKeeper = tasks.first { item in
            item.id == keeperID
        }
        XCTAssertEqual(storedSource?.carriedToTaskID, keeperID)
        XCTAssertEqual(storedSource?.isCarriedForward, true)
        XCTAssertEqual(storedFollower?.carriedFromTaskID, keeperID)
        XCTAssertEqual(storedFollower?.isCarriedForward, true)
        XCTAssertEqual(storedKeeper?.carriedToTaskID, sourceID)
        XCTAssertEqual(storedKeeper?.title, "別")
    }

    /// タスクの並びは sortOrder、作った時刻、id の順。上限の並びがあっても、追加で落ちない。
    func testTaskListOrderAndIntMaxSortOrder() throws {
        guard let earlyID = uuid("00000000-0000-0000-0000-00000000000A"),
              let smallerTieID = uuid("00000000-0000-0000-0000-00000000000B"),
              let largerTieID = uuid("00000000-0000-0000-0000-00000000000C"),
              let maxID = uuid("00000000-0000-0000-0000-00000000000D"),
              let maxMonthID = uuid("00000000-0000-0000-0000-00000000000E") else {
            return
        }
        XCTAssertLessThan(smallerTieID.uuidString, largerTieID.uuidString)
        let (store, context, _) = try makeStore()
        let first = try store.addDailyTask(dateKey: "2026-10-27", title: "先頭")
        guard let daily = first.daily else {
            XCTFail("日ページがありません")
            return
        }
        let tieTime = Date(timeIntervalSince1970: 3_000)
        let early = makeTask(
            id: earlyID,
            title: "早い",
            sortOrder: 2,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let smallerTie = makeTask(
            id: smallerTieID,
            title: "同じ時刻で小さい",
            sortOrder: 2,
            createdAt: tieTime
        )
        let largerTie = makeTask(
            id: largerTieID,
            title: "同じ時刻で大きい",
            sortOrder: 2,
            createdAt: tieTime
        )
        let maximum = makeTask(
            id: maxID,
            title: "上限",
            sortOrder: Int.max,
            createdAt: Date(timeIntervalSince1970: 500)
        )
        context.insert(early)
        context.insert(smallerTie)
        context.insert(largerTie)
        context.insert(maximum)
        early.daily = daily
        smallerTie.daily = daily
        largerTie.daily = daily
        maximum.daily = daily
        try context.save()

        let ordered = try store.tasks(onDaily: daily)
        XCTAssertEqual(
            ordered.map { item in item.id },
            [first.id, earlyID, smallerTieID, largerTieID, maxID]
        )

        let added = try store.addDailyTask(dateKey: "2026-10-27", title: "上限の次")
        XCTAssertEqual(added.sortOrder, Int.max)
        XCTAssertEqual(maximum.sortOrder, Int.max)

        let monthTask = try store.addMonthlyTask(monthKey: "2026-11", title: "月")
        guard let monthlyPage = monthTask.monthly else {
            XCTFail("月ページがありません")
            return
        }
        let maxMonth = makeTask(
            id: maxMonthID,
            title: "月の上限",
            scopeRaw: TaskScope.monthly.rawValue,
            sortOrder: Int.max,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        context.insert(maxMonth)
        maxMonth.monthly = monthlyPage
        try context.save()

        let monthOrdered = try store.tasks(onMonthly: monthlyPage)
        XCTAssertEqual(monthOrdered.map { item in item.id }, [monthTask.id, maxMonthID])
        let addedMonth = try store.addMonthlyTask(monthKey: "2026-11", title: "月の次")
        XCTAssertEqual(addedMonth.sortOrder, Int.max)
        XCTAssertEqual(maxMonth.sortOrder, Int.max)
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

    private func uuid(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UUID? {
        guard let id = UUID(uuidString: text) else {
            XCTFail("UUID の文字列を読めませんでした", file: file, line: line)
            return nil
        }
        return id
    }

    private final class ThrowSwitch {
        var isOn = false
    }

    private enum ForcedSaveError: Error, Equatable {
        case forced
    }

    private func makeThrowingStore(
        shouldThrow: @escaping () -> Bool
    ) throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let instant = fixedNow
        let store = JournalStore(context: context, now: { instant }, save: { modelContext in
            if shouldThrow() {
                throw ForcedSaveError.forced
            }
            try modelContext.save()
        })
        return (store, context, container)
    }

    private func makeTask(
        id: UUID,
        title: String,
        scopeRaw: String = TaskScope.daily.rawValue,
        sortOrder: Int,
        createdAt: Date
    ) -> JournalTask {
        JournalTask(
            id: id,
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

    private func assertNoStoredRecords(
        in context: ModelContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0, file: file, line: line)
    }
}
