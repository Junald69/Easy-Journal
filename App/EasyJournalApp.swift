import SwiftUI

/// アプリの入口。画面には「Easy Journal」と出すだけ。
@main
struct EasyJournalApp: App {
    /// 起動引数を読むだけ。
    /// サンプルデータを入れる処理や、指定した画面を開く処理は、ここにあとで中身を入れる（T-109）。
    private let launchOptions = LaunchOptions()

    var body: some Scene {
        WindowGroup {
            title
        }
    }

    /// 見た目は「Easy Journal」のまま。読んだ起動引数は、まだ画面に使わない。
    private var title: some View {
        _ = launchOptions
        return Text("Easy Journal")
    }
}
