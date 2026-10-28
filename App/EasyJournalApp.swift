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
/// Debug のとき、見本を入れてよいかは `SampleData.shouldInstall` が決める。
/// 条件を満たすときだけ見本を入れる。入れ損ねても、クラッシュさせず、そのまま起動する。
/// `-openPage` で画面を開く処理は、まだ入れない（T-110）。
@main
struct EasyJournalApp: App {
    /// 開けた保存の入れ物。失敗したときは nil。
    private let modelContainer: ModelContainer?
    /// 失敗したときの説明。成功したときは nil。
    private let storageErrorMessage: String?

    init() {
        let options = LaunchOptions()
        do {
            let container = try StorageLocation.makeContainer(inMemory: options.inMemoryStore)
            modelContainer = container
            storageErrorMessage = nil
            // Release（配布向けの組み立て）では、この塊ごと無い。見本は入らない。
            #if DEBUG
            if SampleData.shouldInstall(
                sampleDataRequested: options.sampleData,
                inMemoryStore: options.inMemoryStore
            ) {
                let context = ModelContext(container)
                let store = JournalStore(context: context)
                do {
                    try SampleData.install(into: store, context: context)
                } catch {
                    // 見本は最後まで入らない。途中まで保存された分はメモリ上に残ることがある。起動は続ける。
                }
            }
            #endif
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
