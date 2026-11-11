import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// ◀▶ で開く月。ページは findOrCreateMonthly だけが作る。メモリ上の保存だけ。
final class MonthNavigationStoreTests: XCTestCase {
    /// 2026年10月→11月→10月。11月は1枚だけ。10月の行とタスクは残る。
    func testOctoberNovemberOctoberRoundTrip() throws {
        let (store, context, _) = try makeStore()
        let october = try store.findOrCreateMonthly(monthKey: "2026-10")
        try store.setLogLine(dateKey: "2026-10-03", text: "十月")
        _ = try store.addMonthlyTask(monthKey: "2026-10", title: "十月のタスク")

        let novemberKey = try XCTUnwrap(DateKey.nextMonthKey(after: "2026-10"))
        XCTAssertEqual(novemberKey, "2026-11")
        let november = try store.findOrCreateMonthly(monthKey: novemberKey)
        let novemberAgain = try store.findOrCreateMonthly(monthKey: novemberKey)
        XCTAssertEqual(november.id, novemberAgain.id)
        XCTAssertNotEqual(october.id, november.id)

        let backKey = try XCTUnwrap(DateKey.previousMonthKey(before: novemberKey))
        XCTAssertEqual(backKey, "2026-10")
        let octoberAgain = try store.findOrCreateMonthly(monthKey: backKey)
        XCTAssertEqual(octoberAgain.id, october.id)

        XCTAssertEqual(try monthlyPageCount(in: context), 2)
        XCTAssertEqual(try store.monthlyLogContent(monthKey: "2026-10").textByDateKey["2026-10-03"], "十月")
        XCTAssertEqual(
            try store.monthlyTasks(monthKey: "2026-10").map { task in task.title },
            ["十月のタスク"]
        )
    }

    /// 2026年12月→2027年1月。年が変わる。1月は新しく1枚。
    func testDecemberMovesToNextJanuary() throws {
        let (store, context, _) = try makeStore()
        try store.setLogLine(dateKey: "2026-12-31", text: "大晦日")
        let januaryKey = try XCTUnwrap(DateKey.nextMonthKey(after: "2026-12"))
        XCTAssertEqual(januaryKey, "2027-01")
        XCTAssertNil(try store.findMonthly(monthKey: januaryKey))

        let january = try store.findOrCreateMonthly(monthKey: januaryKey)
        XCTAssertEqual(january.monthKey, "2027-01")
        XCTAssertEqual(try monthlyPageCount(monthKey: "2027-01", in: context), 1)
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-12")?.monthKey, "2026-12")
        XCTAssertEqual(try store.monthlyLogContent(monthKey: "2026-12").textByDateKey["2026-12-31"], "大晦日")
        XCTAssertTrue(try store.monthlyLogContent(monthKey: "2027-01").textByDateKey.isEmpty)
        XCTAssertTrue(try store.monthlyTasks(monthKey: "2027-01").isEmpty)
    }

    /// 2027年1月→2026年12月。前の年に戻る。12月の記録は残る。
    func testJanuaryMovesToPreviousDecember() throws {
        let (store, _) = try makeStore()
        _ = try store.addMonthlyTask(monthKey: "2026-12", title: "年の瀬")
        try store.setLogLine(dateKey: "2027-01-01", text: "元日")
        let decemberKey = try XCTUnwrap(DateKey.previousMonthKey(before: "2027-01"))
        XCTAssertEqual(decemberKey, "2026-12")

        let december = try store.findOrCreateMonthly(monthKey: decemberKey)
        let again = try store.findOrCreateMonthly(monthKey: decemberKey)
        XCTAssertEqual(december.id, again.id)
        XCTAssertEqual(
            try store.monthlyTasks(monthKey: "2026-12").map { task in task.title },
            ["年の瀬"]
        )
        XCTAssertEqual(try store.monthlyLogContent(monthKey: "2027-01").textByDateKey["2027-01-01"], "元日")
        XCTAssertTrue(try store.monthlyLogContent(monthKey: "2026-12").textByDateKey.isEmpty)
        XCTAssertTrue(try store.monthlyTasks(monthKey: "2027-01").isEmpty)
    }

    /// 新しい月は1枚できる。同じ月へ何度開いても増えない。
    func testNewMonthIsCreatedOnceAndReused() throws {
        let (store, context, _) = try makeStore()
        XCTAssertNil(try store.findMonthly(monthKey: "2026-11"))
        let created = try store.findOrCreateMonthly(monthKey: "2026-11")
        XCTAssertEqual(created.monthKey, "2026-11")
        XCTAssertEqual(try monthlyPageCount(monthKey: "2026-11", in: context), 1)
        XCTAssertEqual(try monthlyIndexCount(monthKey: "2026-11", in: context), 1)

        _ = try store.findOrCreateMonthly(monthKey: "2026-11")
        _ = try store.findOrCreateMonthly(monthKey: "2026-11")
        XCTAssertEqual(try monthlyPageCount(monthKey: "2026-11", in: context), 1)
        XCTAssertEqual(try monthlyIndexCount(monthKey: "2026-11", in: context), 1)
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-11")?.id, created.id)
    }

    /// 月ごとの1行とタスクは混ざらない。移ったあとも、元の月の記録は残る。
    func testMonthsDoNotMixAndOriginalRecordsRemain() throws {
        let (store, _) = try makeStore()
        try store.setLogLine(dateKey: "2026-10-03", text: "十月の3日")
        try store.setLogLine(dateKey: "2026-11-03", text: "十一月の3日")
        _ = try store.addMonthlyTask(monthKey: "2026-10", title: "十月のタスク")
        _ = try store.addMonthlyTask(monthKey: "2026-11", title: "十一月のタスク")

        let novemberKey = try XCTUnwrap(DateKey.nextMonthKey(after: "2026-10"))
        _ = try store.findOrCreateMonthly(monthKey: novemberKey)
        let novemberLog = try store.monthlyLogContent(monthKey: novemberKey)
        XCTAssertEqual(novemberLog.textByDateKey["2026-11-03"], "十一月の3日")
        XCTAssertNil(novemberLog.textByDateKey["2026-10-03"])
        XCTAssertFalse(novemberLog.textByDateKey.values.contains("十月の3日"))
        XCTAssertEqual(
            try store.monthlyTasks(monthKey: novemberKey).map { task in task.title },
            ["十一月のタスク"]
        )

        let backKey = try XCTUnwrap(DateKey.previousMonthKey(before: novemberKey))
        let octoberLog = try store.monthlyLogContent(monthKey: backKey)
        XCTAssertEqual(octoberLog.textByDateKey["2026-10-03"], "十月の3日")
        XCTAssertNil(octoberLog.textByDateKey["2026-11-03"])
        XCTAssertEqual(
            try store.monthlyTasks(monthKey: backKey).map { task in task.title },
            ["十月のタスク"]
        )
    }

    /// 1行の保存に失敗したら、元の文章は残り、移動先の月は作らない。判定も月を止める。
    func testLogSaveFailureKeepsStoredTextAndCancelsMove() throws {
        let flag = ThrowSwitch()
        let (store, context, _) = try makeThrowingStore(shouldThrow: { flag.isOn })
        try store.setLogLine(dateKey: "2026-10-03", text: "元")
        flag.isOn = true

        XCTAssertThrowsError(try store.setLogLine(dateKey: "2026-10-03", text: "新しい")) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-03")?.text, "元")
        XCTAssertNil(try store.findMonthly(monthKey: "2026-11"))

        let outcome = MonthMoveRule.result(of: MonthMoveRule.Attempt(
            currentMonthKey: "2026-10",
            destinationMonthKey: "2026-11",
            isEditingLog: true,
            needsDeleteConfirmation: false,
            logDraft: "新しい",
            logSaveSucceeded: false,
            loadFailed: false,
            taskDraft: "",
            pageSaveSucceeded: true,
            destinationLoadSucceeded: true
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertEqual(outcome.logDraft, "新しい")
        XCTAssertTrue(outcome.isEditingLog)
        XCTAssertTrue(outcome.blockedBySaveOrLoad)
    }

    /// 新しい月の保存に失敗したら、ページは増えず、元の月の記録も残る。
    func testNewMonthSaveFailureLeavesOriginalAndCancelsMove() throws {
        let flag = ThrowSwitch()
        let (store, context, _) = try makeThrowingStore(shouldThrow: { flag.isOn })
        try store.setLogLine(dateKey: "2026-10-03", text: "残る")
        _ = try store.addMonthlyTask(monthKey: "2026-10", title: "残るタスク")
        let pagesBefore = try monthlyPageCount(in: context)
        flag.isOn = true

        XCTAssertThrowsError(try store.findOrCreateMonthly(monthKey: "2026-11")) { error in
            XCTAssertEqual(error as? ForcedSaveError, .forced)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertNil(try store.findMonthly(monthKey: "2026-11"))
        XCTAssertEqual(try monthlyPageCount(in: context), pagesBefore)
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-03")?.text, "残る")
        XCTAssertEqual(
            try store.monthlyTasks(monthKey: "2026-10").map { task in task.title },
            ["残るタスク"]
        )

        let outcome = MonthMoveRule.result(of: MonthMoveRule.Attempt(
            currentMonthKey: "2026-10",
            destinationMonthKey: "2026-11",
            isEditingLog: false,
            needsDeleteConfirmation: false,
            logDraft: "",
            logSaveSucceeded: true,
            loadFailed: false,
            taskDraft: "",
            pageSaveSucceeded: false,
            destinationLoadSucceeded: true
        ))
        XCTAssertEqual(outcome.monthKey, "2026-10")
        XCTAssertTrue(outcome.blockedBySaveOrLoad)
    }

    // MARK: - ヘルパー

    private func makeStore() throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = JournalStore(context: context, now: { fixedNow })
        return (store, context, container)
    }

    private func makeThrowingStore(
        shouldThrow: @escaping () -> Bool
    ) throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = JournalStore(context: context, now: { fixedNow }, save: { modelContext in
            if shouldThrow() {
                throw ForcedSaveError.forced
            }
            try modelContext.save()
        })
        return (store, context, container)
    }

    private var fixedNow: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func monthlyPageCount(
        monthKey: String? = nil,
        in context: ModelContext
    ) throws -> Int {
        let pages = try context.fetch(FetchDescriptor<MonthlyPage>())
        guard let monthKey else {
            return pages.count
        }
        return pages.filter { page in
            page.monthKey == monthKey
        }.count
    }

    private func monthlyIndexCount(monthKey: String, in context: ModelContext) throws -> Int {
        let pages = try context.fetch(FetchDescriptor<Page>())
        return pages.filter { page in
            page.kindRaw == PageKind.monthly.rawValue && page.monthKey == monthKey
        }.count
    }

    private final class ThrowSwitch {
        var isOn = false
    }

    private enum ForcedSaveError: Error, Equatable {
        case forced
    }
}
