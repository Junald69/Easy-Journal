import SwiftData
import SwiftUI

/// 月の左ページ（Monthly Log）。読むだけ。保存先には書かない。
///
/// 上のボタンは、まだ動かない。押しても何もしない。
struct MonthlyLogPageView: View {
    /// 表示する月（`yyyy-MM`）。
    let monthKey: String
    /// 今日の日付キー（`yyyy-MM-dd`）。帯とスクロールに使う。
    let todayKey: String

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        loadedBody(load())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                GridPaperBackground()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("monthlyLogScreen")
    }

    private func loadedBody(_ snapshot: MonthlyLogSnapshot) -> some View {
        VStack(spacing: 0) {
            topBar
            logList(snapshot)
            if snapshot.failed {
                Text("記録を読み込めませんでした")
                    .font(DesignTokens.Fonts.subText)
                    .foregroundStyle(DesignTokens.inkSub)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(DesignTokens.Spacing.s)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            barButton(
                systemName: "line.3.horizontal",
                label: "目次",
                identifier: "monthlyMenuButton"
            )
            Text(monthTitle(monthText: monthKey))
                .font(DesignTokens.Fonts.heading)
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("monthlyTitle")
            barButton(
                systemName: "chevron.left",
                label: "前の月",
                identifier: "monthlyPreviousButton"
            )
            barButton(
                systemName: "chevron.right",
                label: "次の月",
                identifier: "monthlyNextButton"
            )
            Button(action: {}) {
                Text("+Daily")
                    .font(DesignTokens.Fonts.bodyText)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .tint(DesignTokens.accent)
            .accessibilityLabel("Dailyを追加")
            .accessibilityIdentifier("monthlyAddDailyButton")
        }
        .padding(.horizontal, DesignTokens.Spacing.m)
        .padding(.vertical, DesignTokens.Spacing.s)
    }

    /// まだ動かないボタン。見た目は押せる。中身は空。
    private func barButton(systemName: String, label: String, identifier: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(DesignTokens.Fonts.bodyText)
        }
        .buttonStyle(.bordered)
        .tint(DesignTokens.accent)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func logList(_ snapshot: MonthlyLogSnapshot) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("MONTHLY LOG")
                        .font(DesignTokens.Fonts.subText)
                        .foregroundStyle(DesignTokens.inkSub)
                        .padding(.horizontal, DesignTokens.Spacing.l)
                        .padding(.vertical, DesignTokens.Spacing.s)
                    ForEach(snapshot.rows, id: \.dateKey) { row in
                        logRow(row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                scrollToToday(in: snapshot.rows, proxy: proxy)
            }
        }
    }

    private func scrollToToday(in rows: [MonthlyLogRow], proxy: ScrollViewProxy) {
        var todayIsInThisMonth = false
        for row in rows {
            if row.isToday {
                todayIsInThisMonth = true
            }
        }
        if todayIsInThisMonth {
            proxy.scrollTo(todayKey, anchor: .center)
        }
    }

    private func logRow(_ row: MonthlyLogRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.s) {
            Text(String(row.dayNumber))
                .font(DesignTokens.Fonts.bodyText)
                .foregroundStyle(dayColor(isWeekend: row.isWeekend))
                .frame(minWidth: DesignTokens.gridSize * 2, alignment: .trailing)
            Text(shortWeekday(row.weekday))
                .font(DesignTokens.Fonts.bodyText)
                .foregroundStyle(dayColor(isWeekend: row.isWeekend))
                .frame(minWidth: DesignTokens.gridSize * 2, alignment: .leading)
            Text(row.text)
                .font(DesignTokens.Fonts.bodyText)
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if row.hasDaily {
                Image(systemName: "doc.text")
                    .font(DesignTokens.Fonts.bodyText)
                    .foregroundStyle(DesignTokens.accent)
                    .accessibilityLabel("Dailyあり")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.gridSize * 2, alignment: .leading)
        .background(row.isToday ? DesignTokens.todayBand : Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel(for: row))
        .accessibilityIdentifier("monthlyLogRow-" + row.dateKey)
        .id(row.dateKey)
    }

    /// 環境の読み書きの窓口から、月の行を読む。失敗してもクラッシュしない。
    private func load() -> MonthlyLogSnapshot {
        let store = JournalStore(context: modelContext)
        do {
            let content = try store.monthlyLogContent(monthKey: monthKey)
            let rows = MonthlyLogRows.make(
                monthKey: monthKey,
                textByDateKey: content.textByDateKey,
                dailyDateKeys: content.dailyDateKeys,
                todayKey: todayKey,
                calendar: DateKey.makeCalendar()
            )
            return MonthlyLogSnapshot(rows: rows, failed: false)
        } catch {
            return MonthlyLogSnapshot(rows: [], failed: true)
        }
    }

    private func monthTitle(monthText: String) -> String {
        guard DateKey.isValidMonthKey(monthText) else {
            return monthText
        }
        let parts = monthText.split(separator: "-")
        guard parts.count == 2, let monthNumber = Int(parts[1]) else {
            return monthText
        }
        return "\(parts[0])年 \(monthNumber)月"
    }

    private func dayColor(isWeekend: Bool) -> Color {
        if isWeekend {
            return DesignTokens.accent
        }
        return DesignTokens.ink
    }

    private func shortWeekday(_ dayOfWeek: DateKey.Weekday) -> String {
        switch dayOfWeek {
        case .sunday:
            return "日"
        case .monday:
            return "月"
        case .tuesday:
            return "火"
        case .wednesday:
            return "水"
        case .thursday:
            return "木"
        case .friday:
            return "金"
        case .saturday:
            return "土"
        }
    }

    private func spokenWeekday(_ dayOfWeek: DateKey.Weekday) -> String {
        switch dayOfWeek {
        case .sunday:
            return "日曜日"
        case .monday:
            return "月曜日"
        case .tuesday:
            return "火曜日"
        case .wednesday:
            return "水曜日"
        case .thursday:
            return "木曜日"
        case .friday:
            return "金曜日"
        case .saturday:
            return "土曜日"
        }
    }

    /// 1行を、読み上げ用の1つの文にする。空の日に「未記入」とは言わない。
    private func spokenLabel(for row: MonthlyLogRow) -> String {
        var parts: [String] = [
            String(row.dayNumber) + "日",
            spokenWeekday(row.weekday)
        ]
        if row.isToday {
            parts.append("今日")
        }
        if row.hasDaily {
            parts.append("Dailyあり")
        }
        if row.text.isEmpty == false {
            parts.append(row.text)
        }
        return parts.joined(separator: " ")
    }
}

/// 読み出しの結果。画面の中だけで使う。
private struct MonthlyLogSnapshot {
    var rows: [MonthlyLogRow]
    var failed: Bool
}
