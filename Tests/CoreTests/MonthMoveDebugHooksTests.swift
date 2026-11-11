import XCTest
@testable import EasyJournal

/// 画面テスト用の印。Debug かつメモリ上の保存先のときだけ有効。
final class MonthMoveDebugHooksTests: XCTestCase {
    func testFailureInjectionRequiresDebugAndInMemoryStore() {
        XCTAssertEqual(
            MonthMoveFailureInjection.fromLaunchArgument(
                "save",
                inMemoryStore: true,
                isDebugBuild: true
            ),
            .save
        )
        XCTAssertEqual(
            MonthMoveFailureInjection.fromLaunchArgument(
                "load",
                inMemoryStore: true,
                isDebugBuild: true
            ),
            .load
        )
        XCTAssertEqual(
            MonthMoveFailureInjection.fromLaunchArgument(
                "log",
                inMemoryStore: true,
                isDebugBuild: true
            ),
            .log
        )
        XCTAssertNil(
            MonthMoveFailureInjection.fromLaunchArgument(
                "log",
                inMemoryStore: false,
                isDebugBuild: true
            )
        )
        XCTAssertNil(
            MonthMoveFailureInjection.fromLaunchArgument(
                "save",
                inMemoryStore: false,
                isDebugBuild: true
            )
        )
        XCTAssertNil(
            MonthMoveFailureInjection.fromLaunchArgument(
                "load",
                inMemoryStore: true,
                isDebugBuild: false
            )
        )
        XCTAssertNil(
            MonthMoveFailureInjection.fromLaunchArgument(
                "other",
                inMemoryStore: true,
                isDebugBuild: true
            )
        )
        XCTAssertNil(
            MonthMoveFailureInjection.fromLaunchArgument(
                nil,
                inMemoryStore: true,
                isDebugBuild: true
            )
        )
    }

    func testDebugJumpMonthRequiresAValidMonthKey() {
        XCTAssertEqual(
            MonthMoveDebugJump.monthKey(
                argument: "2026-11",
                inMemoryStore: true,
                isDebugBuild: true
            ),
            "2026-11"
        )
        XCTAssertNil(
            MonthMoveDebugJump.monthKey(
                argument: "2026-13",
                inMemoryStore: true,
                isDebugBuild: true
            )
        )
        XCTAssertNil(
            MonthMoveDebugJump.monthKey(
                argument: "2026-11",
                inMemoryStore: true,
                isDebugBuild: false
            )
        )
        XCTAssertNil(
            MonthMoveDebugJump.monthKey(
                argument: "2026-11",
                inMemoryStore: false,
                isDebugBuild: true
            )
        )
    }

    func testDebugOpenURLRequiresTheAppSchemeAndInMemoryStore() throws {
        let tracker = try XCTUnwrap(
            MonthMoveDebugOpen.url(
                argument: "easyjournal://tracker/2026-10",
                inMemoryStore: true,
                isDebugBuild: true
            )
        )
        XCTAssertEqual(tracker.absoluteString, "easyjournal://tracker/2026-10")
        XCTAssertNil(
            MonthMoveDebugOpen.url(
                argument: "https://example.com",
                inMemoryStore: true,
                isDebugBuild: true
            )
        )
        XCTAssertNil(
            MonthMoveDebugOpen.url(
                argument: "easyjournal://daily/2026-10-27",
                inMemoryStore: false,
                isDebugBuild: true
            )
        )
        XCTAssertNil(
            MonthMoveDebugOpen.url(
                argument: "easyjournal://daily/2026-10-27",
                inMemoryStore: true,
                isDebugBuild: false
            )
        )
        XCTAssertNil(
            MonthMoveDebugOpen.url(
                argument: nil,
                inMemoryStore: true,
                isDebugBuild: true
            )
        )
    }
}
