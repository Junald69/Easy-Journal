import XCTest
@testable import EasyJournal

/// 起動引数 `-inMemoryStore` と `-openPage` を読めるか。
/// 引数の配列を渡せるので、アプリは起動しない。
final class LaunchOptionsTests: XCTestCase {
    func testManyMonthlyTasksFixtureRequiresExplicitArgumentDebugAndMemoryStore() {
        for requested in [false, true] {
            for memory in [false, true] {
                for debug in [false, true] {
                    var arguments = ["EasyJournal"]
                    if requested { arguments.append("-uiTestManyMonthlyTasks") }
                    if memory { arguments.append("-inMemoryStore") }
                    let options = LaunchOptions(arguments: arguments)
                    XCTAssertEqual(options.shouldInstallManyMonthlyTasks(isDebugBuild: debug),
                                   requested && memory && debug)
                }
            }
        }
    }

    func testReadsInMemoryStoreArgument() {
        let enabled = LaunchOptions(arguments: ["EasyJournal", "-inMemoryStore"])
        XCTAssertTrue(enabled.inMemoryStore)

        let disabled = LaunchOptions(arguments: ["EasyJournal", "-sampleData"])
        XCTAssertFalse(disabled.inMemoryStore)
        XCTAssertTrue(disabled.sampleData)
    }

    func testReadsOpenPageArgument() {
        let options = LaunchOptions(arguments: ["EasyJournal", "-openPage", "monthly:2026-10"])
        XCTAssertEqual(options.openPage, "monthly:2026-10")
    }

    func testReadsMonthMoveDebugArguments() {
        let options = LaunchOptions(arguments: [
            "EasyJournal",
            "-inMemoryStore",
            "-failMonthMove",
            "load",
            "-debugJumpMonth",
            "2026-11",
            "-debugOpenURL",
            "easyjournal://tracker/2026-10",
        ])
        XCTAssertTrue(options.inMemoryStore)
        XCTAssertEqual(options.failMonthMove, "load")
        XCTAssertEqual(options.debugJumpMonth, "2026-11")
        XCTAssertEqual(options.debugOpenURL, "easyjournal://tracker/2026-10")

        let absent = LaunchOptions(arguments: ["EasyJournal"])
        XCTAssertNil(absent.failMonthMove)
        XCTAssertNil(absent.debugJumpMonth)
        XCTAssertNil(absent.debugOpenURL)
    }
}
