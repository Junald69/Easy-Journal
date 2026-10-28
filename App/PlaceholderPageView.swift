import SwiftUI

/// 本物の月ページなどができるまでの、仮の画面。
///
/// 「Easy Journal」の文字は残す。UIテスト（画面を起動して確かめるテスト）がこの文字を探す。
/// その下に、いま開いているページを文字で出す。
struct PlaceholderPageView: View {
    /// アプリが持つ Router。この画面は、いまのページを読むだけ。
    let router: Router

    var body: some View {
        VStack(spacing: 16) {
            // 「Easy Journal」は残す。UIテストがこの文字を探す。
            Text("Easy Journal")
            Text(router.current.openPageText)
                .accessibilityIdentifier("currentPageText")
        }
        .padding()
    }
}
