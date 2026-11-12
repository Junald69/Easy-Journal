import Foundation

/// 起動時に渡された引数を読む小さな型。
/// 読むだけ。見本を入れる処理は `SampleData`。ここには置かない。
/// `-openPage` は、うしろの文字列をここに入れるだけ。最初のページにする処理は `LaunchPage`。
struct LaunchOptions {
    /// `-sampleData` が付いているとき true。
    let sampleData: Bool
    /// 大量タスク UI テストの準備を明示的に要求する。投入は Debug・メモリ内限定。
    let manyMonthlyTasksFixture: Bool

    /// `-openPage` の次に書かれた文字列。無ければ nil。
    let openPage: String?

    /// `-inMemoryStore` が付いているとき true。
    /// 画面テストが、App Group の保存先に触れないための印。メモリ上だけにする。
    let inMemoryStore: Bool

    /// `-todayKey` の次に書かれた文字列。無ければ nil。
    /// ここで読むだけ。今日として使うかは、アプリの起動側が決める。
    let todayKey: String?

    /// `-failMonthMove` の次に書かれた文字列。無ければ nil。
    /// `save` か `load`。使うかは、アプリの起動側が決める。
    let failMonthMove: String?

    /// `-debugJumpMonth` の次に書かれた文字列。無ければ nil。
    /// 月キー。使うかは、アプリの起動側が決める。
    let debugJumpMonth: String?

    /// `-debugOpenURL` の次に書かれた文字列。無ければ nil。
    /// `easyjournal://` の住所。使うかは、アプリの起動側が決める。
    let debugOpenURL: String?

    func shouldInstallManyMonthlyTasks(isDebugBuild: Bool) -> Bool {
        isDebugBuild && inMemoryStore && manyMonthlyTasksFixture
    }

    /// `ProcessInfo.processInfo.arguments` から読む。
    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        var sampleData = false
        var openPage: String?
        var inMemoryStore = false
        var todayKey: String?
        var failMonthMove: String?
        var debugJumpMonth: String?
        var debugOpenURL: String?
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "-sampleData" {
                sampleData = true
            } else if argument == "-openPage" {
                let valueIndex = index + 1
                if valueIndex < arguments.count {
                    openPage = arguments[valueIndex]
                    index = valueIndex
                }
            } else if argument == "-inMemoryStore" {
                inMemoryStore = true
            } else if argument == "-todayKey" {
                let valueIndex = index + 1
                if valueIndex < arguments.count {
                    todayKey = arguments[valueIndex]
                    index = valueIndex
                }
            } else if argument == "-failMonthMove" {
                let valueIndex = index + 1
                if valueIndex < arguments.count {
                    failMonthMove = arguments[valueIndex]
                    index = valueIndex
                }
            } else if argument == "-debugJumpMonth" {
                let valueIndex = index + 1
                if valueIndex < arguments.count {
                    debugJumpMonth = arguments[valueIndex]
                    index = valueIndex
                }
            } else if argument == "-debugOpenURL" {
                let valueIndex = index + 1
                if valueIndex < arguments.count {
                    debugOpenURL = arguments[valueIndex]
                    index = valueIndex
                }
            }
            index += 1
        }
        self.manyMonthlyTasksFixture = arguments.contains("-uiTestManyMonthlyTasks")
        self.sampleData = sampleData
        self.openPage = openPage
        self.inMemoryStore = inMemoryStore
        self.todayKey = todayKey
        self.failMonthMove = failMonthMove
        self.debugJumpMonth = debugJumpMonth
        self.debugOpenURL = debugOpenURL
    }
}
