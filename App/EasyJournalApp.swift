import SwiftData
import SwiftUI

/// アプリの入口。
///
/// 起動時に保存の入れ物（`ModelContainer`）を作る。
/// 成功したときは、今までどおり「Easy Journal」と出す。
/// 失敗したときは、クラッシュさせず、エラーの画面を出す。
/// データを消したり、別の場所に作り直したりはしない。
///
/// `-inMemoryStore` が付いているときだけ、メモリ上の保存先を使う。
/// サンプルデータや、指定した画面を開く処理は、まだここでは使わない（T-109）。
/// 記録を書き込む処理も、まだ入れない（T-105 以降）。
@main
struct EasyJournalApp: App {
    /// 開けた保存の入れ物。失敗したときは nil。
    private let modelContainer: ModelContainer?
    /// 失敗したときの説明。成功したときは nil。
    private let storageErrorMessage: String?

    init() {
        let inMemory = LaunchOptions().inMemoryStore
        do {
            modelContainer = try StorageLocation.makeContainer(inMemory: inMemory)
            storageErrorMessage = nil
        } catch {
            modelContainer = nil
            storageErrorMessage = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                // 画面の文字は変えない。UIテストは「Easy Journal」を探す。
                Text("Easy Journal")
                    .modelContainer(modelContainer)
            } else {
                VStack(spacing: 16) {
                    Text("保存先を開けませんでした。")
                    Text(storageErrorMessage ?? "")
                }
                .padding()
            }
        }
    }
}
