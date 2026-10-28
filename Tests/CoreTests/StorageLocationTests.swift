import SwiftData
import XCTest
@testable import EasyJournal

/// メモリ上だけの保存設定を確認する。
///
/// アプリ本体を `@testable import EasyJournal` している。
/// `Sources/Core` をテスト側の sources には入れていない。
/// 同じファイルを両方に入れると、型が二重になることがあるため。
/// この分け方は T-006 から変えていない。
final class StorageLocationTests: XCTestCase {
    func testInMemoryConfigurationIsStoredInMemoryOnly() {
        let configuration = StorageLocation.modelConfiguration(inMemory: true)
        XCTAssertTrue(configuration.isStoredInMemoryOnly)
    }
}
