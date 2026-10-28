import SwiftUI

/// アプリの入口。画面には「Easy Journal」と出すだけ。
/// 起動引数（`LaunchOptions`）は、T-109 までここでは使わない。
@main
struct EasyJournalApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Easy Journal")
        }
    }
}
