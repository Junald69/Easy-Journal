import SwiftData
import XCTest
@testable import EasyJournal

/// メモリ上だけの保存設定を確認する。
///
/// アプリ本体を `@testable import EasyJournal` している。
/// `Sources/Core` をテスト側の sources には入れていない。
/// この選び方が正しいかは、まだビルドしていないので未確認。
final class StorageLocationTests: XCTestCase {
    func testInMemoryConfigurationIsStoredInMemoryOnly() {
        let configuration = StorageLocation.modelConfiguration(inMemory: true)
        XCTAssertTrue(configuration.isStoredInMemoryOnly)
    }
}
