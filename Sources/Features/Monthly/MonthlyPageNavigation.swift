import SwiftUI

/// Router が確定したページだけを示す。未承諾のスワイプ位置は保存しない。
struct MonthlyPageNavigation: View {
    let currentPage: PageRef
    let requestPage: (PageRef) -> Void

    var body: some View {
        HStack(spacing: 0) {
            pageButton(tracker: false)
            pageButton(tracker: true)
        }
        .accessibilityElement(children: .contain)
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
