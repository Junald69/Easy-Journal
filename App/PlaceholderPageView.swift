import SwiftUI

/// 本物の月ページなどができるまでの、仮の画面。
///
/// 「Easy Journal」の文字は残す。UIテスト（画面を起動して確かめるテスト）がこの文字を探す。
/// その下に、いま開いているページを文字で出す。
/// 背景は方眼の紙。色・余白・文字は DesignTokens（名前を付けた色や余白）から使う。
struct PlaceholderPageView: View {
    /// アプリが持つ Router。この画面は、いまのページを読むだけ。
    let router: Router

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.l) {
            // 「Easy Journal」は残す。UIテストがこの文字を探す。
            Text("Easy Journal")
                .font(DesignTokens.Fonts.heading)
                .foregroundStyle(DesignTokens.ink)
            Text(router.current.openPageText)
                .font(DesignTokens.Fonts.subText)
                .foregroundStyle(DesignTokens.inkSub)
                .accessibilityIdentifier("currentPageText")
        }
        .padding(DesignTokens.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GridPaperBackground()
        }
    }
}
