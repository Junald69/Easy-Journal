import Foundation

/// 起動時に渡された引数を読む小さな型。
/// いまは読むだけ。サンプルデータを入れる処理や、指定した画面を開く処理は、ここにあとで中身を入れる（T-109）。
struct LaunchOptions {
    /// `-sampleData` が付いているとき true。
    let sampleData: Bool

    /// `-openPage` の次に書かれた文字列。無ければ nil。
    let openPage: String?

    /// `ProcessInfo.processInfo.arguments` から読む。
    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        var sampleData = false
        var openPage: String?
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
            }
            index += 1
        }
        self.sampleData = sampleData
        self.openPage = openPage
    }
}
