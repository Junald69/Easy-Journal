import SwiftData
import XCTest
@testable import EasyJournal

final class MonthlyTrackerTests: XCTestCase {
    func testPastTodayFutureAndMonthBoundaries() {
        for (day, month, today, allowed) in [
            ("2024-02-29", "2024-02", "2024-03-01", true),
            ("2026-10-27", "2026-10", "2026-10-27", true),
            ("2026-10-28", "2026-10", "2026-10-27", false),
            ("2026-10-28", "2026-10", "2026-10-28", true),
            ("2026-12-31", "2026-12", "2027-01-01", true),
            ("2026-11-01", "2026-10", "2026-11-02", false),
            ("2026-02-29", "2026-02", "2026-03-01", false),
            ("2026-10-27", "2026-10", "invalid", false),
        ] {
            XCTAssertEqual(MonthlyTrackerRules.mayToggle(dateKey: day, monthKey: month, todayKey: today), allowed)
        }
    }

    func testReadEmptyMonthCreatesNoRecordsAndRejectsInvalidMonth() throws {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = JournalStore(context: context)
        XCTAssertEqual(try store.monthlyTrackerContent(monthKey: "2026-10"),
                       MonthlyTrackerContent(columns: [], checks: []))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)
        XCTAssertThrowsError(try store.monthlyTrackerContent(monthKey: "2026-13"))
    }

    func testSortedColumnsMonthIsolationAndSavedChecksReload() throws {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = JournalStore(context: context)
        let october = try store.findOrCreateMonthly(monthKey: "2026-10")
        let november = try store.findOrCreateMonthly(monthKey: "2026-11")
        let later = Habit(name: "水", shortLabel: "水", sortOrder: 1)
        let first = Habit(name: "歩く", shortLabel: "歩", sortOrder: 0)
        let other = Habit(name: "別月", shortLabel: "別")
        for habit in [later, first, other] { context.insert(habit) }
        later.monthly = october
        first.monthly = october
        other.monthly = november
        try context.save()
        _ = try store.toggleHabit(habitID: first.id, dateKey: "2026-10-26")
        _ = try store.toggleHabit(habitID: other.id, dateKey: "2026-11-01")
        let reloaded = JournalStore(context: ModelContext(container))
        let content = try reloaded.monthlyTrackerContent(monthKey: "2026-10")
        XCTAssertEqual(content.columns.map { $0.id }, [first.id, later.id])
        XCTAssertEqual(content.checks, [.init(habitID: first.id, dateKey: "2026-10-26")])
        _ = try store.toggleHabit(habitID: first.id, dateKey: "2026-10-26")
        XCTAssertTrue(try JournalStore(context: ModelContext(container))
            .monthlyTrackerContent(monthKey: "2026-10").checks.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
    }

    func testFailedSaveRollsBackCheckAndAllowsRetry() throws {
        enum Failure: Error { case forced }
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = JournalStore(context: context)
        let month = try store.findOrCreateMonthly(monthKey: "2026-10")
        let habit = Habit(name: "水", shortLabel: "水")
        context.insert(habit)
        habit.monthly = month
        try context.save()
        let failing = JournalStore(context: context, save: { _ in throw Failure.forced })
        XCTAssertThrowsError(try failing.toggleHabit(habitID: habit.id, dateKey: "2026-10-27"))
        XCTAssertTrue(try store.monthlyTrackerContent(monthKey: "2026-10").checks.isEmpty)
        _ = try store.toggleHabit(habitID: habit.id, dateKey: "2026-10-27")
        XCTAssertEqual(try store.monthlyTrackerContent(monthKey: "2026-10").checks.count, 1)
    }
}
