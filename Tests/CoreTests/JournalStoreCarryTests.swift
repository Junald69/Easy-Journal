import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// タスクの繰越と取り消し。メモリ上の保存だけ。
final class JournalStoreCarryTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    /// 翌日の Daily が無いとき、自動で作る。誰が作ったかは carryOver。
    /// コピーの名前・進み具合・ID、元の印、履歴、ページのつながりを確かめる。
    func testCarryForwardCreatesNextDailyWhenMissing() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "画面のラフ")
        let sourceID = source.id
        XCTAssertNil(try store.findDaily(dateKey: "2026-10-28"))

        let copy = try store.carryForward(taskID: sourceID)

        XCTAssertEqual(copy.title, "画面のラフ")
        XCTAssertEqual(copy.scope, .daily)
        XCTAssertEqual(copy.scopeRaw, TaskScope.daily.rawValue)
        XCTAssertEqual(copy.progress, .open)
        XCTAssertEqual(copy.progressRaw, TaskProgress.open.rawValue)
        XCTAssertFalse(copy.isCarriedForward)
        XCTAssertEqual(copy.carriedFromTaskID, sourceID)
        XCTAssertNil(copy.carriedToTaskID)
        XCTAssertEqual(copy.sortOrder, 0)
        XCTAssertEqual(copy.createdAt, fixedNow)
        XCTAssertNil(copy.completedAt)
        XCTAssertNil(copy.monthly)
        XCTAssertEqual(copy.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(copy.daily?.page?.createdBy, .carryOver)
        XCTAssertEqual(copy.daily?.page?.createdByRaw, PageCreatedBy.carryOver.rawValue)
        XCTAssertEqual(copy.daily?.page?.monthKey, "2026-10")

        XCTAssertTrue(source.isCarriedForward)
        XCTAssertEqual(source.progress, .open)
        XCTAssertEqual(source.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(source.carriedToTaskID, copy.id)
        XCTAssertNil(source.carriedFromTaskID)
        XCTAssertEqual(source.title, "画面のラフ")
        XCTAssertEqual(source.sortOrder, 0)
        XCTAssertNil(source.completedAt)
        XCTAssertEqual(source.daily?.dateKey, "2026-10-27")
        XCTAssertEqual(source.daily?.page?.createdBy, .user)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertFalse(context.hasChanges)

        let carried = try histories(
            in: context,
            taskID: sourceID,
            actionRaw: TaskHistoryAction.carriedForward.rawValue
        )
        XCTAssertEqual(carried.count, 1)
        XCTAssertEqual(carried.first?.action, .carriedForward)
        XCTAssertEqual(carried.first?.fromProgress, .open)
        XCTAssertEqual(carried.first?.toProgress, .open)
        XCTAssertEqual(carried.first?.fromProgressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(carried.first?.toProgressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(carried.first?.relatedTaskID, copy.id)
        XCTAssertEqual(carried.first?.relatedDateKey, "2026-10-28")
        XCTAssertEqual(carried.first?.at, fixedNow)

        let created = try histories(
            in: context,
            taskID: copy.id,
            actionRaw: TaskHistoryAction.created.rawValue
        )
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created.first?.action, .created)
        XCTAssertNil(created.first?.fromProgress)
        XCTAssertNil(created.first?.fromProgressRaw)
        XCTAssertEqual(created.first?.toProgress, .open)
        XCTAssertEqual(created.first?.toProgressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(created.first?.relatedTaskID, sourceID)
        XCTAssertEqual(created.first?.relatedDateKey, "2026-10-27")
        XCTAssertEqual(created.first?.at, fixedNow)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 3)

        let links = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.type, .carryOver)
        XCTAssertEqual(links.first?.typeRaw, PageLinkType.carryOver.rawValue)
        XCTAssertEqual(links.first?.fromPageID, source.daily?.page?.id)
        XCTAssertEqual(links.first?.toPageID, copy.daily?.page?.id)
        XCTAssertNotEqual(links.first?.fromPageID, source.daily?.id)
        XCTAssertNotEqual(links.first?.toPageID, copy.daily?.id)
    }

    /// 翌日の Daily が、人の操作ですでにあるときは作らない。並びは最大 + 1 で末尾。
    func testCarryForwardAppendsToExistingDailyUsingMaxSortOrder() throws {
        let (store, context, _) = try makeStore()
        let existing = try store.addDailyTask(dateKey: "2026-10-28", title: "既存")
        guard let nextDaily = existing.daily else {
            XCTFail("翌日の日ページがありません")
            return
        }
        XCTAssertEqual(nextDaily.page?.createdBy, .user)
        let high = JournalTask(
            title: "大きい並び",
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: nil,
            carriedToTaskID: nil,
            sortOrder: 7,
            createdAt: Date(timeIntervalSince1970: 1_600_000_000),
            completedAt: nil
        )
        context.insert(high)
        high.daily = nextDaily
        try context.save()

        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "元")
        let copy = try store.carryForward(taskID: source.id)

        XCTAssertEqual(copy.sortOrder, 8)
        XCTAssertEqual(copy.daily?.id, nextDaily.id)
        XCTAssertEqual(existing.sortOrder, 0)
        XCTAssertEqual(high.sortOrder, 7)
        XCTAssertEqual(nextDaily.page?.createdBy, .user)
        XCTAssertEqual(nextDaily.page?.createdByRaw, PageCreatedBy.user.rawValue)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 4)
        let ordered = try store.tasks(onDaily: nextDaily)
        XCTAssertEqual(ordered.map { item in item.sortOrder }, [0, 7, 8])
        XCTAssertEqual(ordered.last?.id, copy.id)
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 1)
    }

    /// 一部（partial）も繰越できる。コピーも元も partial のまま。
    func testCarryForwardCopiesPartialProgress() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "途中")
        let partial = try store.cycleProgress(taskID: source.id)
        XCTAssertEqual(partial, .partial)

        let copy = try store.carryForward(taskID: source.id)

        XCTAssertEqual(copy.progress, .partial)
        XCTAssertEqual(copy.progressRaw, TaskProgress.partial.rawValue)
        XCTAssertNil(copy.completedAt)
        XCTAssertFalse(copy.isCarriedForward)
        XCTAssertEqual(source.progress, .partial)
        XCTAssertEqual(source.progressRaw, TaskProgress.partial.rawValue)
        XCTAssertTrue(source.isCarriedForward)
        XCTAssertNil(source.completedAt)
        XCTAssertEqual(copy.daily?.dateKey, "2026-10-28")

        let carried = try histories(
            in: context,
            taskID: source.id,
            actionRaw: TaskHistoryAction.carriedForward.rawValue
        )
        XCTAssertEqual(carried.count, 1)
        XCTAssertEqual(carried.first?.fromProgress, .partial)
        XCTAssertEqual(carried.first?.toProgress, .partial)
        XCTAssertEqual(carried.first?.relatedTaskID, copy.id)
        XCTAssertEqual(carried.first?.relatedDateKey, "2026-10-28")
        let created = try histories(
            in: context,
            taskID: copy.id,
            actionRaw: TaskHistoryAction.created.rawValue
        )
        XCTAssertEqual(created.count, 1)
        XCTAssertNil(created.first?.fromProgressRaw)
        XCTAssertEqual(created.first?.toProgress, .partial)
        XCTAssertEqual(created.first?.relatedTaskID, source.id)
        XCTAssertEqual(created.first?.relatedDateKey, "2026-10-27")
    }

    /// 同じ日の2件目を繰越しても、ページのつながりは1本のまま。
    func testCarryForwardDoesNotDuplicatePageLink() throws {
        let (store, context, _) = try makeStore()
        let first = try store.addDailyTask(dateKey: "2026-10-27", title: "いち")
        let second = try store.addDailyTask(dateKey: "2026-10-27", title: "に")
        let copyA = try store.carryForward(taskID: first.id)
        let linksAfterFirst = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue)
        guard let linkID = linksAfterFirst.first?.id else {
            XCTFail("繰越のつながりがありません")
            return
        }
        XCTAssertEqual(linksAfterFirst.count, 1)

        let copyB = try store.carryForward(taskID: second.id)

        let linksAfterSecond = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue)
        XCTAssertEqual(linksAfterSecond.count, 1)
        XCTAssertEqual(linksAfterSecond.first?.id, linkID)
        XCTAssertEqual(copyA.sortOrder, 0)
        XCTAssertEqual(copyB.sortOrder, 1)
        XCTAssertEqual(copyA.daily?.id, copyB.daily?.id)
        XCTAssertEqual(copyA.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 4)
        XCTAssertTrue(first.isCarriedForward)
        XCTAssertTrue(second.isCarriedForward)
        XCTAssertEqual(first.carriedToTaskID, copyA.id)
        XCTAssertEqual(second.carriedToTaskID, copyB.id)
    }

    /// 10/31 の翌日は 11/1。11月の月ページと結ばれる。
    func testCarryForwardCrossesMonthEnd() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-31", title: "月末")
        let copy = try store.carryForward(taskID: source.id)

        XCTAssertEqual(source.daily?.dateKey, "2026-10-31")
        XCTAssertEqual(copy.daily?.dateKey, "2026-11-01")
        XCTAssertEqual(copy.daily?.page?.monthKey, "2026-11")
        XCTAssertEqual(copy.daily?.page?.createdBy, .carryOver)
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-10")?.monthKey, "2026-10")
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-11")?.monthKey, "2026-11")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)

        guard let toID = copy.daily?.page?.id,
              let novemberPageID = try store.findMonthly(monthKey: "2026-11")?.page?.id else {
            XCTFail("ページの id が取れませんでした")
            return
        }
        let carryLinks = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue)
        XCTAssertEqual(carryLinks.count, 1)
        XCTAssertEqual(carryLinks.first?.fromPageID, source.daily?.page?.id)
        XCTAssertEqual(carryLinks.first?.toPageID, toID)
        let monthLinks = try pageLinks(in: context, typeRaw: PageLinkType.dailyToMonthly.rawValue)
        XCTAssertTrue(monthLinks.contains { link in
            link.fromPageID == toID && link.toPageID == novemberPageID
        })
    }

    /// 12/31 の翌日は翌年の 1/1。1月の月ページと結ばれる。
    func testCarryForwardCrossesYearEnd() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-12-31", title: "年末")
        let copy = try store.carryForward(taskID: source.id)

        XCTAssertEqual(copy.daily?.dateKey, "2027-01-01")
        XCTAssertEqual(copy.daily?.page?.monthKey, "2027-01")
        XCTAssertEqual(copy.daily?.page?.createdBy, .carryOver)
        XCTAssertEqual(source.daily?.page?.monthKey, "2026-12")
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-12")?.monthKey, "2026-12")
        XCTAssertEqual(try store.findMonthly(monthKey: "2027-01")?.monthKey, "2027-01")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)

        guard let toID = copy.daily?.page?.id,
              let januaryPageID = try store.findMonthly(monthKey: "2027-01")?.page?.id else {
            XCTFail("ページの id が取れませんでした")
            return
        }
        let monthLinks = try pageLinks(in: context, typeRaw: PageLinkType.dailyToMonthly.rawValue)
        XCTAssertTrue(monthLinks.contains { link in
            link.fromPageID == toID && link.toPageID == januaryPageID
        })
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 1)
    }

    /// うるう年は 2/28 → 2/29、2/29 → 3/1。
    func testCarryForwardCrossesLeapDay() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2028-02-28", title: "うるう")
        let middle = try store.carryForward(taskID: source.id)
        let last = try store.carryForward(taskID: middle.id)

        XCTAssertEqual(middle.daily?.dateKey, "2028-02-29")
        XCTAssertEqual(middle.daily?.page?.monthKey, "2028-02")
        XCTAssertEqual(middle.daily?.page?.createdBy, .carryOver)
        XCTAssertEqual(last.daily?.dateKey, "2028-03-01")
        XCTAssertEqual(last.daily?.page?.monthKey, "2028-03")
        XCTAssertEqual(last.daily?.page?.createdBy, .carryOver)
        XCTAssertEqual(source.daily?.page?.createdBy, .user)
        XCTAssertEqual(source.daily?.page?.monthKey, "2028-02")
        XCTAssertEqual(try store.findMonthly(monthKey: "2028-02")?.monthKey, "2028-02")
        XCTAssertEqual(try store.findMonthly(monthKey: "2028-03")?.monthKey, "2028-03")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 3)
        XCTAssertTrue(source.isCarriedForward)
        XCTAssertTrue(middle.isCarriedForward)
        XCTAssertFalse(last.isCarriedForward)
        XCTAssertEqual(middle.carriedFromTaskID, source.id)
        XCTAssertEqual(middle.carriedToTaskID, last.id)
        XCTAssertEqual(last.carriedFromTaskID, middle.id)
        XCTAssertNil(last.carriedToTaskID)
    }

    /// A→B→C と2回繰越すると、C の履歴から B、B の履歴から A へたどれる。
    func testCarryForwardChainCanBeTracedThroughHistory() throws {
        let (store, context, _) = try makeStore()
        let taskA = try store.addDailyTask(dateKey: "2026-10-27", title: "A")
        let taskB = try store.carryForward(taskID: taskA.id)
        let taskC = try store.carryForward(taskID: taskB.id)

        XCTAssertEqual(taskB.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(taskC.daily?.dateKey, "2026-10-29")
        XCTAssertEqual(taskB.carriedFromTaskID, taskA.id)
        XCTAssertEqual(taskA.carriedToTaskID, taskB.id)
        XCTAssertEqual(taskC.carriedFromTaskID, taskB.id)
        XCTAssertEqual(taskB.carriedToTaskID, taskC.id)
        XCTAssertNil(taskA.carriedFromTaskID)
        XCTAssertNil(taskC.carriedToTaskID)
        XCTAssertTrue(taskA.isCarriedForward)
        XCTAssertTrue(taskB.isCarriedForward)
        XCTAssertFalse(taskC.isCarriedForward)

        var cursor: UUID? = taskC.id
        var seen: [UUID] = []
        var steps = 0
        while let current = cursor {
            seen.append(current)
            let created = try histories(
                in: context,
                taskID: current,
                actionRaw: TaskHistoryAction.created.rawValue
            )
            cursor = created.first?.relatedTaskID
            steps += 1
            if steps > 5 {
                break
            }
        }
        XCTAssertEqual(seen, [taskC.id, taskB.id, taskA.id])

        let carriedFromA = try histories(
            in: context,
            taskID: taskA.id,
            actionRaw: TaskHistoryAction.carriedForward.rawValue
        )
        XCTAssertEqual(carriedFromA.first?.relatedTaskID, taskB.id)
        XCTAssertEqual(carriedFromA.first?.relatedDateKey, "2026-10-28")
        let carriedFromB = try histories(
            in: context,
            taskID: taskB.id,
            actionRaw: TaskHistoryAction.carriedForward.rawValue
        )
        XCTAssertEqual(carriedFromB.first?.relatedTaskID, taskC.id)
        XCTAssertEqual(carriedFromB.first?.relatedDateKey, "2026-10-29")

        let links = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue)
        XCTAssertEqual(links.count, 2)
        XCTAssertTrue(links.contains { link in
            link.fromPageID == taskA.daily?.page?.id && link.toPageID == taskB.daily?.page?.id
        })
        XCTAssertTrue(links.contains { link in
            link.fromPageID == taskB.daily?.page?.id && link.toPageID == taskC.daily?.page?.id
        })
    }

    /// 完了は繰越できない。翌日のページも、コピーも、履歴も増えない。
    func testCarryForwardRejectsDone() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "完了")
        _ = try store.cycleProgress(taskID: task.id)
        _ = try store.cycleProgress(taskID: task.id)
        XCTAssertEqual(task.progress, .done)
        let tasksBefore = try context.fetchCount(FetchDescriptor<JournalTask>())
        let historiesBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())
        let dailiesBefore = try context.fetchCount(FetchDescriptor<DailyPage>())
        let linksBefore = try context.fetchCount(FetchDescriptor<PageLink>())

        XCTAssertThrowsError(try store.carryForward(taskID: task.id)) { error in
            XCTAssertEqual(error as? JournalStoreError, .cannotCarryForward(task.id))
        }

        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(task.progress, .done)
        XCTAssertFalse(task.isCarriedForward)
        XCTAssertNil(task.carriedToTaskID)
        XCTAssertNil(try store.findDaily(dateKey: "2026-10-28"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), tasksBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historiesBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), dailiesBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), linksBefore)
    }

    /// すでに繰越済みなら、もう一度はできない。コピーもつながりも増えない。
    func testCarryForwardRejectsAlreadyCarried() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "送った")
        let copy = try store.carryForward(taskID: task.id)
        let copyID = copy.id
        let tasksBefore = try context.fetchCount(FetchDescriptor<JournalTask>())
        let historiesBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())
        let dailiesBefore = try context.fetchCount(FetchDescriptor<DailyPage>())
        let linksBefore = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count

        XCTAssertThrowsError(try store.carryForward(taskID: task.id)) { error in
            XCTAssertEqual(error as? JournalStoreError, .cannotCarryForward(task.id))
        }

        XCTAssertFalse(context.hasChanges)
        XCTAssertTrue(task.isCarriedForward)
        XCTAssertEqual(task.progress, .open)
        XCTAssertEqual(task.carriedToTaskID, copyID)
        XCTAssertEqual(copy.carriedFromTaskID, task.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), tasksBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historiesBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), dailiesBefore)
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, linksBefore)
    }

    /// 月のタスクは繰越できない。日ページは作られない。
    func testCarryForwardRejectsMonthlyTask() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addMonthlyTask(monthKey: "2026-10", title: "月の目標")
        let historiesBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())

        XCTAssertThrowsError(try store.carryForward(taskID: task.id)) { error in
            XCTAssertEqual(error as? JournalStoreError, .cannotCarryForward(task.id))
        }

        XCTAssertFalse(context.hasChanges)
        XCTAssertFalse(task.isCarriedForward)
        XCTAssertNil(task.carriedToTaskID)
        XCTAssertEqual(task.scope, .monthly)
        XCTAssertEqual(task.title, "月の目標")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historiesBefore)
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 0)
    }

    /// 無い ID は taskNotFound。何も作らない。
    func testCarryForwardRejectsMissingTask() throws {
        let (store, context, _) = try makeStore()
        let missing = UUID()

        XCTAssertThrowsError(try store.carryForward(taskID: missing)) { error in
            XCTAssertEqual(error as? JournalStoreError, .taskNotFound(missing))
        }

        XCTAssertFalse(context.hasChanges)
        try assertNoStoredRecords(in: context)
    }

    /// コピーが未変更なら消す。元は元の進み具合に戻る。ページのつながりは残る。
    func testCancelCarryForwardDeletesUnmodifiedCopy() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "元")
        _ = try store.cycleProgress(taskID: source.id)
        let copy = try store.carryForward(taskID: source.id)
        let copyID = copy.id
        guard let sourceDailyID = source.daily?.id else {
            XCTFail("元の日ページがありません")
            return
        }

        try store.cancelCarryForward(taskID: source.id)

        XCTAssertEqual(source.progress, .partial)
        XCTAssertEqual(source.progressRaw, TaskProgress.partial.rawValue)
        XCTAssertFalse(source.isCarriedForward)
        XCTAssertNil(source.carriedToTaskID)
        XCTAssertEqual(source.daily?.id, sourceDailyID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 1)
        XCTAssertNil(try context.fetch(FetchDescriptor<JournalTask>()).first { item in
            item.id == copyID
        })
        XCTAssertNotNil(try store.findDaily(dateKey: "2026-10-28"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 1)

        let deleted = try histories(
            in: context,
            taskID: copyID,
            actionRaw: TaskHistoryAction.deleted.rawValue
        )
        XCTAssertEqual(deleted.count, 1)
        XCTAssertEqual(deleted.first?.action, .deleted)
        XCTAssertEqual(deleted.first?.fromProgress, .partial)
        XCTAssertEqual(deleted.first?.fromProgressRaw, TaskProgress.partial.rawValue)
        XCTAssertNil(deleted.first?.toProgressRaw)
        XCTAssertNil(deleted.first?.relatedTaskID)
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: copyID,
                actionRaw: TaskHistoryAction.created.rawValue
            ).count,
            1
        )

        let cancelled = try histories(
            in: context,
            taskID: source.id,
            actionRaw: TaskHistoryAction.carryCancelled.rawValue
        )
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertEqual(cancelled.first?.action, .carryCancelled)
        XCTAssertEqual(cancelled.first?.fromProgress, .partial)
        XCTAssertEqual(cancelled.first?.toProgress, .partial)
        XCTAssertEqual(cancelled.first?.relatedTaskID, copyID)
        XCTAssertEqual(cancelled.first?.relatedDateKey, "2026-10-28")
        XCTAssertEqual(cancelled.first?.at, fixedNow)
    }

    /// コピーの名前を変えたあとは、コピーを残す。元との ID だけ外す。
    func testCancelCarryForwardKeepsCopyAfterTitleEdit() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "元")
        let copy = try store.carryForward(taskID: source.id)
        let copyID = copy.id
        try store.editTaskTitle(taskID: copyID, title: "  変えた  ")

        try store.cancelCarryForward(taskID: source.id)

        XCTAssertEqual(copy.title, "変えた")
        XCTAssertNil(copy.carriedFromTaskID)
        XCTAssertFalse(copy.isCarriedForward)
        XCTAssertEqual(copy.progress, .open)
        XCTAssertEqual(copy.daily?.dateKey, "2026-10-28")
        XCTAssertFalse(source.isCarriedForward)
        XCTAssertNil(source.carriedToTaskID)
        XCTAssertEqual(source.progress, .open)
        XCTAssertEqual(source.title, "元")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 2)
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: copyID,
                actionRaw: TaskHistoryAction.deleted.rawValue
            ).count,
            0
        )
        let cancelled = try histories(
            in: context,
            taskID: source.id,
            actionRaw: TaskHistoryAction.carryCancelled.rawValue
        )
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertEqual(cancelled.first?.relatedTaskID, copyID)
        XCTAssertEqual(cancelled.first?.relatedDateKey, "2026-10-28")
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 1)
    }

    /// コピーの進み具合を変えたあとは、コピーを残す。進み具合はそのまま。
    func testCancelCarryForwardKeepsCopyAfterProgressChange() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "元")
        let copy = try store.carryForward(taskID: source.id)
        let copyID = copy.id
        let changed = try store.cycleProgress(taskID: copyID)
        XCTAssertEqual(changed, .partial)

        try store.cancelCarryForward(taskID: source.id)

        XCTAssertEqual(copy.progress, .partial)
        XCTAssertEqual(copy.progressRaw, TaskProgress.partial.rawValue)
        XCTAssertNil(copy.carriedFromTaskID)
        XCTAssertFalse(copy.isCarriedForward)
        XCTAssertEqual(copy.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(source.progress, .open)
        XCTAssertFalse(source.isCarriedForward)
        XCTAssertNil(source.carriedToTaskID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 2)
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: copyID,
                actionRaw: TaskHistoryAction.deleted.rawValue
            ).count,
            0
        )
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 1)
    }

    /// 繰越先のコピーだけを deleteTask で消したあと、cancelCarryForward で元タスクを戻せる。
    ///
    /// deleteTask は相手の ID だけ空にし、繰越済みの印は変えない。コピーはもう無い。
    /// 取り消しはコピーに触らず、元の印だけを外す。そのあと記号タップで進む。
    func testCancelCarryForwardRestoresSourceWhenCopyWasDeleted() throws {
        let (store, context, container) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "元に戻す")
        let sourceID = source.id
        let copy = try store.carryForward(taskID: sourceID)
        let copyID = copy.id
        XCTAssertTrue(source.isCarriedForward)
        XCTAssertEqual(source.carriedToTaskID, copyID)

        try store.deleteTask(taskID: copyID)

        let midwayTasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(midwayTasks.count, 1)
        XCTAssertEqual(midwayTasks.first?.id, sourceID)
        XCTAssertEqual(midwayTasks.first?.isCarriedForward, true)
        XCTAssertNil(midwayTasks.first?.carriedToTaskID)
        XCTAssertEqual(midwayTasks.first?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(midwayTasks.first?.title, "元に戻す")
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: copyID,
                actionRaw: TaskHistoryAction.deleted.rawValue
            ).count,
            1
        )

        try store.cancelCarryForward(taskID: sourceID)

        let after = ModelContext(container)
        let afterTasks = try after.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(afterTasks.count, 1)
        XCTAssertEqual(afterTasks.first?.id, sourceID)
        XCTAssertEqual(afterTasks.first?.isCarriedForward, false)
        XCTAssertNil(afterTasks.first?.carriedToTaskID)
        XCTAssertEqual(afterTasks.first?.progress, .open)
        XCTAssertEqual(afterTasks.first?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(afterTasks.first?.title, "元に戻す")
        XCTAssertEqual(afterTasks.first?.daily?.dateKey, "2026-10-27")
        XCTAssertNotNil(try after.fetch(FetchDescriptor<DailyPage>()).first { item in
            item.dateKey == "2026-10-28"
        })
        XCTAssertEqual(try pageLinks(in: after, typeRaw: PageLinkType.carryOver.rawValue).count, 1)
        XCTAssertEqual(
            try histories(
                in: after,
                taskID: copyID,
                actionRaw: TaskHistoryAction.deleted.rawValue
            ).count,
            1
        )
        let cancelled = try histories(
            in: after,
            taskID: sourceID,
            actionRaw: TaskHistoryAction.carryCancelled.rawValue
        )
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertNil(cancelled.first?.relatedTaskID)
        XCTAssertNil(cancelled.first?.relatedDateKey)
        XCTAssertEqual(cancelled.first?.fromProgress, .open)
        XCTAssertEqual(cancelled.first?.toProgress, .open)

        let tapped = try store.cycleProgress(taskID: sourceID)
        XCTAssertEqual(tapped, .partial)
        XCTAssertEqual(source.progress, .partial)
        XCTAssertFalse(source.isCarriedForward)
    }

    /// 繰越していないタスクの取り消しはエラー。無い ID もエラー。何も変わらない。
    func testCancelCarryForwardRejectsWhenNotCarried() throws {
        let (store, context, _) = try makeStore()
        let task = try store.addDailyTask(dateKey: "2026-10-27", title: "まだ")
        let historiesBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())

        XCTAssertThrowsError(try store.cancelCarryForward(taskID: task.id)) { error in
            XCTAssertEqual(error as? JournalStoreError, .notCarriedForward(task.id))
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertFalse(task.isCarriedForward)
        XCTAssertNil(task.carriedToTaskID)
        XCTAssertEqual(task.progress, .open)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historiesBefore)
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: task.id,
                actionRaw: TaskHistoryAction.carryCancelled.rawValue
            ).count,
            0
        )

        let missing = UUID()
        XCTAssertThrowsError(try store.cancelCarryForward(taskID: missing)) { error in
            XCTAssertEqual(error as? JournalStoreError, .taskNotFound(missing))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historiesBefore)
    }

    /// 取り消しの前は記号タップで進まない。取り消しのあと進む。
    func testCycleProgressWorksAfterCancelCarryForward() throws {
        let (store, _, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "タップ")
        _ = try store.carryForward(taskID: source.id)

        let blocked = try store.cycleProgress(taskID: source.id)
        XCTAssertEqual(blocked, .open)
        XCTAssertEqual(source.progress, .open)
        XCTAssertTrue(source.isCarriedForward)

        try store.cancelCarryForward(taskID: source.id)
        let tapped = try store.cycleProgress(taskID: source.id)
        XCTAssertEqual(tapped, .partial)
        XCTAssertEqual(source.progress, .partial)
        XCTAssertEqual(source.progressRaw, TaskProgress.partial.rawValue)
        XCTAssertFalse(source.isCarriedForward)
    }

    /// 未変更のコピーを消して取り消したあと、もう一度繰越できる。つながりは増えない。
    func testCarryForwardAgainAfterCancel() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "もう一度")
        let first = try store.carryForward(taskID: source.id)
        let firstID = first.id
        let linksBefore = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue)
        guard let linkID = linksBefore.first?.id else {
            XCTFail("繰越のつながりがありません")
            return
        }

        try store.cancelCarryForward(taskID: source.id)
        let second = try store.carryForward(taskID: source.id)

        XCTAssertNotEqual(second.id, firstID)
        XCTAssertTrue(source.isCarriedForward)
        XCTAssertEqual(source.carriedToTaskID, second.id)
        XCTAssertEqual(source.progress, .open)
        XCTAssertEqual(second.carriedFromTaskID, source.id)
        XCTAssertFalse(second.isCarriedForward)
        XCTAssertEqual(second.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(second.sortOrder, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 2)
        XCTAssertNil(try context.fetch(FetchDescriptor<JournalTask>()).first { item in
            item.id == firstID
        })
        let linksAfter = try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue)
        XCTAssertEqual(linksAfter.count, 1)
        XCTAssertEqual(linksAfter.first?.id, linkID)
    }

    /// 元の carriedToTaskID が、自分のコピーではない別タスクを指していても、その相手は変えない。
    func testCancelCarryForwardLeavesUnrelatedTaskUntouched() throws {
        let (store, context, container) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "元")
        let unrelated = try store.addDailyTask(dateKey: "2026-10-28", title: "別人")
        let sourceID = source.id
        let unrelatedID = unrelated.id
        let strangerID = UUID()
        let forwardID = UUID()
        unrelated.carriedFromTaskID = strangerID
        unrelated.carriedToTaskID = forwardID
        unrelated.isCarriedForward = true
        source.isCarriedForward = true
        source.carriedToTaskID = unrelatedID
        try context.save()
        let historyBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())

        try store.cancelCarryForward(taskID: sourceID)

        let other = ModelContext(container)
        let tasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 2)
        let storedSource = tasks.first { item in
            item.id == sourceID
        }
        let storedOther = tasks.first { item in
            item.id == unrelatedID
        }
        XCTAssertEqual(storedSource?.isCarriedForward, false)
        XCTAssertNil(storedSource?.carriedToTaskID)
        XCTAssertEqual(storedSource?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(storedSource?.title, "元")
        XCTAssertEqual(storedOther?.title, "別人")
        XCTAssertEqual(storedOther?.carriedFromTaskID, strangerID)
        XCTAssertEqual(storedOther?.carriedToTaskID, forwardID)
        XCTAssertEqual(storedOther?.isCarriedForward, true)
        XCTAssertEqual(storedOther?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(storedOther?.sortOrder, unrelated.sortOrder)
        XCTAssertEqual(storedOther?.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(
            try histories(
                in: other,
                taskID: unrelatedID,
                actionRaw: TaskHistoryAction.deleted.rawValue
            ).count,
            0
        )
        let cancelled = try histories(
            in: other,
            taskID: sourceID,
            actionRaw: TaskHistoryAction.carryCancelled.rawValue
        )
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertEqual(cancelled.first?.relatedTaskID, unrelatedID)
        XCTAssertNil(cancelled.first?.relatedDateKey)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore + 1)
    }

    /// A→B→C のあと A を取り消す。B は変更済みとして残り、B から C は残る。
    func testCancelCarryForwardOnChainKeepsLaterLink() throws {
        let (store, context, _) = try makeStore()
        let taskA = try store.addDailyTask(dateKey: "2026-10-27", title: "A")
        let taskB = try store.carryForward(taskID: taskA.id)
        let taskC = try store.carryForward(taskID: taskB.id)
        let taskAID = taskA.id
        let taskBID = taskB.id
        let taskCID = taskC.id
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: taskBID,
                actionRaw: TaskHistoryAction.created.rawValue
            ).count,
            1
        )
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: taskBID,
                actionRaw: TaskHistoryAction.carriedForward.rawValue
            ).count,
            1
        )

        try store.cancelCarryForward(taskID: taskAID)

        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 3)
        let storedA = tasks.first { item in
            item.id == taskAID
        }
        let storedB = tasks.first { item in
            item.id == taskBID
        }
        let storedC = tasks.first { item in
            item.id == taskCID
        }
        XCTAssertEqual(storedA?.isCarriedForward, false)
        XCTAssertNil(storedA?.carriedToTaskID)
        XCTAssertEqual(storedA?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(storedA?.title, "A")
        XCTAssertNil(storedB?.carriedFromTaskID)
        XCTAssertEqual(storedB?.isCarriedForward, true)
        XCTAssertEqual(storedB?.carriedToTaskID, taskCID)
        XCTAssertEqual(storedB?.title, "A")
        XCTAssertEqual(storedB?.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(storedC?.carriedFromTaskID, taskBID)
        XCTAssertEqual(storedC?.isCarriedForward, false)
        XCTAssertNil(storedC?.carriedToTaskID)
        XCTAssertEqual(storedC?.title, "A")
        XCTAssertEqual(storedC?.daily?.dateKey, "2026-10-29")
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: taskBID,
                actionRaw: TaskHistoryAction.deleted.rawValue
            ).count,
            0
        )
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: taskCID,
                actionRaw: TaskHistoryAction.deleted.rawValue
            ).count,
            0
        )
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 2)
    }

    /// あとの保存が失敗したら、コピーと元の変更は残らない。翌日の Daily だけは残ってよい。
    ///
    /// 先に成功する実行で保存回数を数え、最後の1回だけ失敗させる。
    func testCarryForwardRollsBackWhenLaterSaveThrows() throws {
        let saveCount = try measuredSaveCount(
            prepare: { setup in
                try setup.addDailyTask(dateKey: "2026-10-27", title: "残す").id
            },
            operate: { probed, preparedID in
                _ = try probed.carryForward(taskID: preparedID)
            }
        )
        XCTAssertGreaterThan(saveCount, 0)

        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let instant = fixedNow
        let setup = JournalStore(context: context, now: { instant })
        let source = try setup.addDailyTask(dateKey: "2026-10-27", title: "残す")
        let sourceID = source.id
        let historyBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(historyBefore, 1)
        XCTAssertNil(try setup.findDaily(dateKey: "2026-10-28"))

        let tally = SaveTally()
        tally.failAt = saveCount
        let store = probedStore(context: context, tally: tally)

        XCTAssertThrowsError(try store.carryForward(taskID: sourceID)) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }

        XCTAssertEqual(tally.calls, saveCount)
        XCTAssertFalse(context.hasChanges)
        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, sourceID)
        XCTAssertEqual(tasks.first?.title, "残す")
        XCTAssertEqual(tasks.first?.isCarriedForward, false)
        XCTAssertNil(tasks.first?.carriedToTaskID)
        XCTAssertEqual(tasks.first?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)
        XCTAssertEqual(try pageLinks(in: context, typeRaw: PageLinkType.carryOver.rawValue).count, 0)
        // 翌日の Daily だけは残ってよい。この失敗のしかたでは、先に保存されるので残る。
        let nextDaily = try context.fetch(FetchDescriptor<DailyPage>()).first { item in
            item.dateKey == "2026-10-28"
        }
        XCTAssertEqual(nextDaily?.page?.createdByRaw, PageCreatedBy.carryOver.rawValue)
        XCTAssertEqual(nextDaily?.tasks?.count ?? 0, 0)

        let other = ModelContext(container)
        let otherTasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(otherTasks.count, 1)
        XCTAssertEqual(otherTasks.first?.id, sourceID)
        XCTAssertEqual(otherTasks.first?.isCarriedForward, false)
        XCTAssertNil(otherTasks.first?.carriedToTaskID)
        XCTAssertEqual(otherTasks.first?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertNotNil(try other.fetch(FetchDescriptor<DailyPage>()).first { item in
            item.dateKey == "2026-10-28"
        })
        XCTAssertEqual(try pageLinks(in: other, typeRaw: PageLinkType.carryOver.rawValue).count, 0)
    }

    /// 取り消しの保存が失敗したら、元もコピーも履歴も、失敗の前のまま。
    /// 未変更コピーを消す経路。翌日の Daily は、繰越のときに保存済みなので残る（残ってよい）。
    /// 保存回数は、成功する実行で数えて、最後の1回だけ失敗させる。
    func testCancelCarryForwardRollsBackWhenSaveThrows() throws {
        let saveCount = try measuredSaveCount(
            prepare: { setup in
                let source = try setup.addDailyTask(dateKey: "2026-10-27", title: "残す")
                _ = try setup.carryForward(taskID: source.id)
                return source.id
            },
            operate: { probed, preparedID in
                try probed.cancelCarryForward(taskID: preparedID)
            }
        )
        XCTAssertGreaterThan(saveCount, 0)

        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let instant = fixedNow
        let setup = JournalStore(context: context, now: { instant })
        let source = try setup.addDailyTask(dateKey: "2026-10-27", title: "残す")
        let sourceID = source.id
        let copy = try setup.carryForward(taskID: sourceID)
        let copyID = copy.id
        let historyBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(historyBefore, 3)

        let tally = SaveTally()
        tally.failAt = saveCount
        let store = probedStore(context: context, tally: tally)

        XCTAssertThrowsError(try store.cancelCarryForward(taskID: sourceID)) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }

        XCTAssertEqual(tally.calls, saveCount)

        XCTAssertFalse(context.hasChanges)
        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 2)
        let storedSource = tasks.first { item in
            item.id == sourceID
        }
        let storedCopy = tasks.first { item in
            item.id == copyID
        }
        XCTAssertEqual(storedSource?.isCarriedForward, true)
        XCTAssertEqual(storedSource?.carriedToTaskID, copyID)
        XCTAssertEqual(storedSource?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(storedCopy?.carriedFromTaskID, sourceID)
        XCTAssertEqual(storedCopy?.title, "残す")
        XCTAssertEqual(storedCopy?.isCarriedForward, false)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)

        let other = ModelContext(container)
        let otherTasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(otherTasks.count, 2)
        let otherSource = otherTasks.first { item in
            item.id == sourceID
        }
        let otherCopy = otherTasks.first { item in
            item.id == copyID
        }
        XCTAssertEqual(otherSource?.isCarriedForward, true)
        XCTAssertEqual(otherSource?.carriedToTaskID, copyID)
        XCTAssertEqual(otherCopy?.carriedFromTaskID, sourceID)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)
        // 翌日の Daily は残ってよい。取り消しの前から保存されているので、失敗しても残る。
        XCTAssertNotNil(try other.fetch(FetchDescriptor<DailyPage>()).first { item in
            item.dateKey == "2026-10-28"
        })
    }

    /// 変更済みコピーを残す取り消しで、保存が失敗したら、元もコピーも戻る。
    /// 保存回数は、成功する実行で数えて、最後の1回だけ失敗させる。
    func testCancelCarryForwardRollsBackModifiedCopyWhenSaveThrows() throws {
        let saveCount = try measuredSaveCount(
            prepare: { setup in
                let source = try setup.addDailyTask(dateKey: "2026-10-27", title: "残す")
                let copy = try setup.carryForward(taskID: source.id)
                try setup.editTaskTitle(taskID: copy.id, title: "変えた")
                return source.id
            },
            operate: { probed, preparedID in
                try probed.cancelCarryForward(taskID: preparedID)
            }
        )
        XCTAssertGreaterThan(saveCount, 0)

        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let instant = fixedNow
        let setup = JournalStore(context: context, now: { instant })
        let source = try setup.addDailyTask(dateKey: "2026-10-27", title: "残す")
        let sourceID = source.id
        let copy = try setup.carryForward(taskID: sourceID)
        let copyID = copy.id
        try setup.editTaskTitle(taskID: copyID, title: "変えた")
        let historyBefore = try context.fetchCount(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(historyBefore, 4)

        let tally = SaveTally()
        tally.failAt = saveCount
        let store = probedStore(context: context, tally: tally)

        XCTAssertThrowsError(try store.cancelCarryForward(taskID: sourceID)) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }

        XCTAssertEqual(tally.calls, saveCount)
        XCTAssertFalse(context.hasChanges)
        let tasks = try context.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 2)
        let storedSource = tasks.first { item in
            item.id == sourceID
        }
        let storedCopy = tasks.first { item in
            item.id == copyID
        }
        XCTAssertEqual(storedSource?.isCarriedForward, true)
        XCTAssertEqual(storedSource?.carriedToTaskID, copyID)
        XCTAssertEqual(storedSource?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(storedSource?.title, "残す")
        XCTAssertEqual(storedCopy?.title, "変えた")
        XCTAssertEqual(storedCopy?.carriedFromTaskID, sourceID)
        XCTAssertEqual(storedCopy?.isCarriedForward, false)
        XCTAssertNil(storedCopy?.carriedToTaskID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)
        XCTAssertEqual(
            try histories(
                in: context,
                taskID: sourceID,
                actionRaw: TaskHistoryAction.carryCancelled.rawValue
            ).count,
            0
        )

        let other = ModelContext(container)
        let otherTasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(otherTasks.count, 2)
        let otherSource = otherTasks.first { item in
            item.id == sourceID
        }
        let otherCopy = otherTasks.first { item in
            item.id == copyID
        }
        XCTAssertEqual(otherSource?.isCarriedForward, true)
        XCTAssertEqual(otherSource?.carriedToTaskID, copyID)
        XCTAssertEqual(otherCopy?.title, "変えた")
        XCTAssertEqual(otherCopy?.carriedFromTaskID, sourceID)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<TaskHistory>()), historyBefore)
        XCTAssertNotNil(try other.fetch(FetchDescriptor<DailyPage>()).first { item in
            item.dateKey == "2026-10-28"
        })
    }

    /// 別の読み書き窓口から、繰越の結果が保存されている。
    func testCarriedTaskIsVisibleFromAnotherContext() throws {
        let (store, _, container) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "残る元")
        let sourceID = source.id
        let copy = try store.carryForward(taskID: sourceID)
        let copyID = copy.id

        let other = ModelContext(container)
        let tasks = try other.fetch(FetchDescriptor<JournalTask>())
        XCTAssertEqual(tasks.count, 2)
        let storedSource = tasks.first { item in
            item.id == sourceID
        }
        let storedCopy = tasks.first { item in
            item.id == copyID
        }
        XCTAssertEqual(storedSource?.title, "残る元")
        XCTAssertEqual(storedSource?.isCarriedForward, true)
        XCTAssertEqual(storedSource?.carriedToTaskID, copyID)
        XCTAssertEqual(storedSource?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(storedSource?.daily?.dateKey, "2026-10-27")
        XCTAssertEqual(storedCopy?.title, "残る元")
        XCTAssertEqual(storedCopy?.isCarriedForward, false)
        XCTAssertEqual(storedCopy?.carriedFromTaskID, sourceID)
        XCTAssertNil(storedCopy?.carriedToTaskID)
        XCTAssertEqual(storedCopy?.progressRaw, TaskProgress.open.rawValue)
        XCTAssertEqual(storedCopy?.scopeRaw, TaskScope.daily.rawValue)
        XCTAssertEqual(storedCopy?.daily?.dateKey, "2026-10-28")
        XCTAssertEqual(storedCopy?.daily?.page?.createdByRaw, PageCreatedBy.carryOver.rawValue)

        let carried = try histories(
            in: other,
            taskID: sourceID,
            actionRaw: TaskHistoryAction.carriedForward.rawValue
        )
        XCTAssertEqual(carried.count, 1)
        XCTAssertEqual(carried.first?.relatedTaskID, copyID)
        XCTAssertEqual(carried.first?.relatedDateKey, "2026-10-28")
        let created = try histories(
            in: other,
            taskID: copyID,
            actionRaw: TaskHistoryAction.created.rawValue
        )
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created.first?.relatedTaskID, sourceID)
        XCTAssertEqual(created.first?.relatedDateKey, "2026-10-27")
        let links = try pageLinks(in: other, typeRaw: PageLinkType.carryOver.rawValue)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.fromPageID, storedSource?.daily?.page?.id)
        XCTAssertEqual(links.first?.toPageID, storedCopy?.daily?.page?.id)
    }

    /// 繰越と取り消しのあとでも、すでにある履歴の中身は変わらない。足すだけ。
    func testCarryHistoryIsAppendOnly() throws {
        let (store, context, _) = try makeStore()
        let source = try store.addDailyTask(dateKey: "2026-10-27", title: "履歴")
        _ = try store.carryForward(taskID: source.id)

        let before = try context.fetch(FetchDescriptor<TaskHistory>())
        let snapshot = before.map { item in
            HistoryStamp(
                id: item.id,
                taskID: item.taskID,
                actionRaw: item.actionRaw,
                fromProgressRaw: item.fromProgressRaw,
                toProgressRaw: item.toProgressRaw,
                relatedTaskID: item.relatedTaskID,
                relatedDateKey: item.relatedDateKey,
                at: item.at
            )
        }
        XCTAssertEqual(snapshot.count, 3)

        try store.cancelCarryForward(taskID: source.id)

        let after = try context.fetch(FetchDescriptor<TaskHistory>())
        XCTAssertEqual(after.count, snapshot.count + 2)
        for stamp in snapshot {
            let matches = after.filter { item in
                item.id == stamp.id
            }
            XCTAssertEqual(matches.count, 1)
            XCTAssertEqual(matches.first?.taskID, stamp.taskID)
            XCTAssertEqual(matches.first?.actionRaw, stamp.actionRaw)
            XCTAssertEqual(matches.first?.fromProgressRaw, stamp.fromProgressRaw)
            XCTAssertEqual(matches.first?.toProgressRaw, stamp.toProgressRaw)
            XCTAssertEqual(matches.first?.relatedTaskID, stamp.relatedTaskID)
            XCTAssertEqual(matches.first?.relatedDateKey, stamp.relatedDateKey)
            XCTAssertEqual(matches.first?.at, stamp.at)
        }
    }

    // MARK: - ヘルパー

    private struct HistoryStamp: Equatable {
        let id: UUID
        let taskID: UUID
        let actionRaw: String
        let fromProgressRaw: String?
        let toProgressRaw: String?
        let relatedTaskID: UUID?
        let relatedDateKey: String?
        let at: Date
    }

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

    private final class SaveTally {
        var calls = 0
        var failAt: Int?
    }

    private enum ForcedSaveError: Error, Equatable {
        case forced
    }

    /// 保存の回数を数える。failAt 回目だけ失敗させる。1 から数える。
    private func probedStore(context: ModelContext, tally: SaveTally) -> JournalStore {
        let instant = fixedNow
        return JournalStore(context: context, now: { instant }, save: { modelContext in
            tally.calls += 1
            if tally.failAt == tally.calls {
                throw ForcedSaveError.forced
            }
            try modelContext.save()
        })
    }

    /// 準備の保存は数えない。そのあとの操作が呼んだ保存の回数だけ返す。
    private func measuredSaveCount(
        prepare: (JournalStore) throws -> UUID,
        operate: (JournalStore, UUID) throws -> Void
    ) throws -> Int {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let instant = fixedNow
        let setup = JournalStore(context: context, now: { instant })
        let preparedID = try prepare(setup)
        let tally = SaveTally()
        let store = probedStore(context: context, tally: tally)
        try operate(store, preparedID)
        return tally.calls
    }

    private func histories(
        in context: ModelContext,
        taskID: UUID,
        actionRaw: String
    ) throws -> [TaskHistory] {
        let stored = try context.fetch(FetchDescriptor<TaskHistory>())
        return stored.filter { item in
            item.taskID == taskID && item.actionRaw == actionRaw
        }
    }

    private func pageLinks(in context: ModelContext, typeRaw: String) throws -> [PageLink] {
        let stored = try context.fetch(FetchDescriptor<PageLink>())
        return stored.filter { link in
            link.typeRaw == typeRaw
        }
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
