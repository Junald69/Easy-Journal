import XCTest
@testable import EasyJournal

/// 起動引数 `-inMemoryStore` を読めるか。
/// 引数の配列を渡せるので、アプリは起動しない。
final class LaunchOptionsTests: XCTestCase {
    func testReadsInMemoryStoreArgument() {
        let enabled = LaunchOptions(arguments: ["EasyJournal", "-inMemoryStore"])
        XCTAssertTrue(enabled.inMemoryStore)

        let disabled = LaunchOptions(arguments: ["EasyJournal", "-sampleData"])
        XCTAssertFalse(disabled.inMemoryStore)
        XCTAssertTrue(disabled.sampleData)
    }
}
