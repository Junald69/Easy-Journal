import Foundation
import SwiftData
import SwiftUI

/// アプリの入口。
///
/// 起動時に保存の入れ物（`ModelContainer`）を作る。
/// 成功したときは、月の記録なら Monthly Log の画面、それ以外は仮の画面を出す。
/// 失敗したときは、クラッシュさせず、エラーの画面を出す。
/// データを消したり、別の場所に作り直したりはしない。
///
/// `-inMemoryStore` が付いているときだけ、メモリ上の保存先を使う。
/// Debug のとき、見本を入れてよいかは `SampleData.shouldInstall` が決める。
/// 条件を満たすときだけ見本を入れる。入れ損ねても、クラッシュさせず、そのまま起動する。
/// `-openPage` の文字列が読めたときは、そのページを最初のページにする。
/// 無いか、読めないときは、いまの月の記録（Monthly Log）のまま。
/// `-todayKey` は、Debug かつ `-inMemoryStore` のときだけ、「今日」を固定する。
@main
struct EasyJournalApp: App {
    /// 開けた保存の入れ物。失敗したときは nil。
    private let modelContainer: ModelContainer?
    /// 失敗したときの説明。成功したときは nil。
    private let storageErrorMessage: String?
    /// 今日の日付キー。月の画面に渡す。起動のときに1回決める。
    private let todayKey: String
    /// 今どのページを開いているか。成功の画面だけに渡す。
    @State private var router: Router

    init() {
        let options = LaunchOptions()
        let calendar = DateKey.makeCalendar()
        let now = Date()
        let launchRouter = LaunchPage.makeRouter(
            openPage: options.openPage,
            now: now,
            calendar: calendar
        )
        _router = State(initialValue: launchRouter)
        todayKey = EasyJournalApp.resolvedTodayKey(options: options, now: now, calendar: calendar)
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
                RootPageView(router: router, todayKey: todayKey)
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

    /// 「今日」の日付キー。普段は、いまの時計と端末の暦。
    ///
    /// `-todayKey` を使うのは、Debug かつメモリ上の保存先のときだけ。
    /// 値が日付キーとして読めないときは、普段の今日のまま。
    /// Release（配布向けの組み立て）では、引数があっても使わない。
    static func resolvedTodayKey(options: LaunchOptions, now: Date, calendar: Calendar) -> String {
        let usual = DateKey.todayKey(now: now, calendar: calendar)
        #if DEBUG
        if options.inMemoryStore,
           let requested = options.todayKey,
           DateKey.isValidDayKey(requested) {
            return requested
        }
        #else
        // Release では -todayKey を使わない。引数は読んでも捨てる。
        _ = options.todayKey
        #endif
        return usual
    }
}
