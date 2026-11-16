import SwiftUI

/// Router が確定したページだけを示す。未承諾のスワイプ位置は保存しない。
struct MonthlyPageNavigation: View {
    let currentPage: PageRef
    let requestPage: (PageRef) -> Void

    var body: some View {
        HStack(spacing: 0) {
            swipeArea(identifier: "monthlyPageSwipeLeading")
            pageButton(tracker: false)
            pageButton(tracker: true)
            swipeArea(identifier: "monthlyPageSwipeTrailing")
        }
        .accessibilityElement(children: .contain)
    }

    /// ボタン・入力欄・スクロールの祖先にはジェスチャーを付けない。
    /// 左右の余白のみをスワイプの入口にして、操作領域を重ねない。
    private func swipeArea(identifier: String) -> some View {
        Color.clear
            .frame(minWidth: 44, maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 30).onEnded { gesture in
                guard let month = currentPage.monthlyKey,
                      abs(gesture.translation.width) > 40,
                      abs(gesture.translation.width) > abs(gesture.translation.height) * 1.5 else { return }
                if gesture.translation.width < 0 && currentPage.isMonthlyTracker == false {
                    requestPage(.monthlyTracker(monthKey: month))
                } else if gesture.translation.width > 0 && currentPage.isMonthlyTracker {
                    requestPage(.monthlyLog(monthKey: month))
                }
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("左右にスワイプしてページを切り替え")
            .accessibilityIdentifier(identifier)
    }

    private func pageButton(tracker: Bool) -> some View {
        let selected = currentPage.isMonthlyTracker == tracker
        return Button {
            guard let month = currentPage.monthlyKey else { return }
            requestPage(tracker ? .monthlyTracker(monthKey: month) : .monthlyLog(monthKey: month))
        } label: {
            Image(systemName: selected ? "circle.fill" : "circle")
                .font(.caption)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tracker ? "右ページ" : "左ページ")
        .accessibilityValue(selected ? "選択中" : "未選択")
        .accessibilityIdentifier(tracker ? "monthlyRightPageButton" : "monthlyLeftPageButton")
    }
}

/// 先行 PR はナビゲーションのみ。習慣の読取・保存は後続 PR で実装する。
struct MonthlyTrackerPlaceholder: View {
    let monthKey: String
    var body: some View {
        VStack(spacing: 16) {
            Text("HABIT TRACKER").font(DesignTokens.Fonts.heading)
            Text("習慣表は準備中です").font(DesignTokens.Fonts.bodyText)
            Text("tracker:" + monthKey).accessibilityIdentifier("currentPageText")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
