import Combine
import Foundation
import SwiftData
import SwiftUI
import UIKit

/// アプリの入口。
///
/// 起動時に保存の入れ物（`ModelContainer`）を作る。
/// 成功したときは、月の記録なら Monthly Log の画面、それ以外は仮の画面を出す。
/// 失敗したときは、クラッシュさせず、エラーの画面を出す。
/// データを消したり、別の場所に作り直したりはしない。
///
/// `-inMemoryStore` が付いているときだけ、メモリ上の保存先を使う。
/// Debug のとき、見本を入れてよいかは `SampleData.shouldInstall` が決める。
/// 条件を満たすときだけ見本を入れる。投入に失敗したら、クラッシュさせず、起動エラーを表示する。
/// `-openPage` の文字列が読めたときは、そのページを最初のページにする。
/// 無いか、読めないときは、いまの月の記録（Monthly Log）のまま。
/// 開いている月は、起動のときに決める。日付が変わっても月は動かさない。
/// ◀▶ と、外からの月の依頼と、月の画面を出る開き方は、確認と保存ができたときだけページを変える。
/// `-todayKey` は、Debug かつ `-inMemoryStore` のときだけ、「今日」を固定する。
/// 今日の日付キーは、起動時だけでなく、画面に戻ったときと、日やタイムゾーンが変わったときにも計算し直す。
@main
struct EasyJournalApp: App {
    /// 開けた保存の入れ物。失敗したときは nil。
    private let modelContainer: ModelContainer?
    /// 失敗したときの説明。成功したときは nil。
    private let storageErrorMessage: String?
    /// 起動引数。今日の再計算でも、同じ条件で固定日を見る。
    private let launchOptions: LaunchOptions
    /// Debug かつメモリ上の保存先のときだけ、次の月移動を1回失敗させる。
    private let monthMoveFailure: MonthMoveFailureInjection?
    /// Debug かつメモリ上の保存先のときだけ、◀▶ と同じ確認を通して開く月。
    private let debugJumpMonth: String?
    /// Debug かつメモリ上の保存先のときだけ、確認を通して開く URL。
    private let debugOpenURL: URL?
    /// 画面テストのときだけ、アニメーションを止める。タップがアニメーションに遮られないようにする。
    private let animationsDisabled: Bool
    /// 今日の日付キー。月の画面に渡す。同じ日なら書き換えない。
    @State private var todayKey: String
    /// 今どのページを開いているか。成功の画面だけに渡す。
    @State private var router: Router
    /// シーンが前面にいるか。アクティブに戻ったときに今日を計算し直す。
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let options = LaunchOptions()
        launchOptions = options
        let now = Date()
        let calendar = DateKey.makeCalendar()
        let launchRouter = LaunchPage.makeRouter(
            openPage: options.openPage,
            now: now,
            calendar: calendar
        )
        _router = State(initialValue: launchRouter)
        _todayKey = State(
            initialValue: TodayKeyResolver.resolve(
                fixedDayKey: options.todayKey,
                inMemoryStore: options.inMemoryStore,
                isDebugBuild: EasyJournalApp.debugBuild,
                now: now,
                calendar: calendar
            )
        )
        monthMoveFailure = MonthMoveFailureInjection.fromLaunchArgument(
            options.failMonthMove,
            inMemoryStore: options.inMemoryStore,
            isDebugBuild: EasyJournalApp.debugBuild
        )
        debugJumpMonth = MonthMoveDebugJump.monthKey(
            argument: options.debugJumpMonth,
            inMemoryStore: options.inMemoryStore,
            isDebugBuild: EasyJournalApp.debugBuild
        )
        debugOpenURL = MonthMoveDebugOpen.url(
            argument: options.debugOpenURL,
            inMemoryStore: options.inMemoryStore,
            isDebugBuild: EasyJournalApp.debugBuild
        )
        // 画面テストはメモリ上の保存先で動く。アニメーションが残ると、ボタンが押せないまま待ちが伸びる。
        animationsDisabled = EasyJournalApp.debugBuild && options.inMemoryStore
        if animationsDisabled {
            UIView.setAnimationsEnabled(false)
        }
        do {
            let container = try StorageLocation.makeContainer(inMemory: options.inMemoryStore)
            // Release（配布向けの組み立て）では、この塊ごと無い。見本は入らない。
            #if DEBUG
            if SampleData.shouldInstall(
                sampleDataRequested: options.sampleData,
                inMemoryStore: options.inMemoryStore
            ) {
                let context = ModelContext(container)
                let store = JournalStore(context: context)
                try SampleData.install(into: store, context: context)
            }
            if options.shouldInstallManyMonthlyTasks(isDebugBuild: EasyJournalApp.debugBuild) {
                let store = JournalStore(context: ModelContext(container))
                // 固定の準備データ。通常の保存 API を通し、投入失敗は起動エラーにする。
                for index in 0..<7 {
                    _ = try store.addMonthlyTask(monthKey: "2026-10", title: "t" + String(index))
                }
            }
            #endif
            modelContainer = container
            storageErrorMessage = nil
        } catch {
            modelContainer = nil
            storageErrorMessage = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    RootPageView(
                        router: router,
                        todayKey: todayKey,
                        monthMoveFailure: monthMoveFailure,
                        debugJumpMonth: debugJumpMonth,
                        debugOpenURL: debugOpenURL
                    )
                        .modelContainer(modelContainer)
                } else {
                    VStack(spacing: 16) {
                        Text("保存先を開けませんでした。")
                        Text(storageErrorMessage ?? "")
                    }
                    .padding()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshTodayKey(resetTimeZone: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshTodayKey(resetTimeZone: false)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)
            ) { _ in
                refreshTodayKey(resetTimeZone: true)
            }
            .transaction { transaction in
                if animationsDisabled {
                    transaction.disablesAnimations = true
                }
            }
        }
    }

    /// Debug ビルドのときだけ true。Release では false。分岐はここに置く。
    private static var debugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// 今日の日付キーを計算し直す。同じ文字列なら State は変えない。
    ///
    /// 暦は毎回 `DateKey.makeCalendar()` で作り直す。前に作った暦は使い回さない。
    /// タイムゾーンが変わったときは、その前にキャッシュを捨てる。
    private func refreshTodayKey(resetTimeZone: Bool) {
        if resetTimeZone {
            NSTimeZone.resetSystemTimeZone()
        }
        let calendar = DateKey.makeCalendar()
        let resolved = TodayKeyResolver.resolve(
            fixedDayKey: launchOptions.todayKey,
            inMemoryStore: launchOptions.inMemoryStore,
            isDebugBuild: EasyJournalApp.debugBuild,
            now: Date(),
            calendar: calendar
        )
        if resolved != todayKey {
            todayKey = resolved
        }
    }
}
