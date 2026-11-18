import XCTest
@testable import EasyJournal

final class MonthlyTrackerStateTests: XCTestCase {
    private enum Failure: Error { case read, save }
    private let id = UUID()
    private func content(done: Bool = false) -> MonthlyTrackerContent {
        .init(columns: [.init(id: id, name: "水", shortLabel: "水")],
              checks: done ? [.init(habitID: id, dateKey: "2026-10-27")] : [])
    }

    func testReadFailureIsNotEmptyMonthAndRetryCanLoadEmptyMonth() {
        var state = MonthlyTrackerState()
        state.load(monthKey: "2026-10", read: { _ in throw Failure.read })
        XCTAssertNil(state.content)
        XCTAssertEqual(state.problem, .read)
        state.retry(todayKey: "2026-10-27", write: { _, _ in XCTFail("読取再試行は保存しない"); return false },
                    read: { _ in .init(columns: [], checks: []) })
        XCTAssertNil(state.problem)
        XCTAssertEqual(state.content?.columns.count, 0)
    }

    func testDifferentMonthReadFailureNeverKeepsPreviousMonthChecks() {
        var state = MonthlyTrackerState()
        state.load(monthKey: "2026-10", read: { _ in content(done: true) })
        state.load(monthKey: "2026-11", read: { _ in throw Failure.read })
        XCTAssertEqual(state.monthKey, "2026-11")
        XCTAssertNil(state.content)
        XCTAssertEqual(state.problem, .read)
    }

    func testSaveFailureRetainsDisplayAndRetryWritesOnceSuccessfully() {
        var state = MonthlyTrackerState()
        state.load(monthKey: "2026-10", read: { _ in content() })
        state.toggle(habitID: id, dateKey: "2026-10-27", todayKey: "2026-10-27",
                     write: { _, _ in throw Failure.save }, read: { _ in XCTFail("保存失敗後は読まない"); return content() })
        XCTAssertEqual(state.problem, .save)
        XCTAssertTrue(state.content?.checks.isEmpty == true)
        var writes = 0
        state.retry(todayKey: "2026-10-27", write: { _, _ in writes += 1; return true }, read: { _ in content(done: true) })
        XCTAssertEqual(writes, 1)
        XCTAssertNil(state.problem)
        XCTAssertEqual(state.content?.checks.count, 1)
    }

    func testSavedButReadFailedRetryNeverTogglesAgain() {
        var state = MonthlyTrackerState()
        state.load(monthKey: "2026-10", read: { _ in content() })
        var saved = false
        var writes = 0
        let write: (UUID, String) throws -> Bool = { _, _ in saved.toggle(); writes += 1; return saved }
        state.toggle(habitID: id, dateKey: "2026-10-27", todayKey: "2026-10-27", write: write,
                     read: { _ in throw Failure.read })
        XCTAssertTrue(saved)
        XCTAssertEqual(state.problem, .savedButReloadFailed)
        XCTAssertNil(state.content)
        state.retry(todayKey: "2026-10-27", write: write, read: { _ in throw Failure.read })
        XCTAssertEqual(state.problem, .savedButReloadFailed)
        state.retry(todayKey: "2026-10-27", write: write, read: { _ in content(done: saved) })
        XCTAssertEqual(writes, 1)
        XCTAssertTrue(saved)
        XCTAssertEqual(state.content?.checks.count, 1)
        XCTAssertNil(state.problem)
    }

    func testFutureAndWrongMonthAndUnknownHabitCannotWrite() {
        var state = MonthlyTrackerState()
        state.load(monthKey: "2026-10", read: { _ in content() })
        for (habit, date) in [(id, "2026-10-28"), (id, "2026-11-01"), (UUID(), "2026-10-27")] {
            state.toggle(habitID: habit, dateKey: date, todayKey: "2026-10-27",
                         write: { _, _ in XCTFail("変更禁止"); return true }, read: { _ in content() })
        }
        XCTAssertTrue(state.content?.checks.isEmpty == true)
        state.toggle(habitID: id, dateKey: "2026-10-28", todayKey: "2026-10-28",
                     write: { _, _ in true }, read: { _ in content(done: true) })
        XCTAssertEqual(state.content?.checks.count, 1)
    }

    func testMonthChangeDiscardsFailedSaveRetryTarget() {
        var state = MonthlyTrackerState()
        state.load(monthKey: "2026-10", read: { _ in content() })
        state.toggle(habitID: id, dateKey: "2026-10-27", todayKey: "2026-10-27",
                     write: { _, _ in throw Failure.save }, read: { _ in content() })
        state.load(monthKey: "2026-11", read: { _ in .init(columns: [], checks: []) })
        state.retry(todayKey: "2026-10-27", write: { _, _ in XCTFail("前月へ保存しない"); return false },
                    read: { month in XCTAssertEqual(month, "2026-11"); return .init(columns: [], checks: []) })
        XCTAssertNil(state.problem)
    }
}
