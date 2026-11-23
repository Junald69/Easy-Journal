import SwiftData
import SwiftUI

/// Monthly 共通親から渡された確定月だけを表示する。ページ切替ジェスチャーは持たない。
struct MonthlyTrackerPageView: View {
    let monthKey: String
    let todayKey: String
    @Environment(\.modelContext) private var modelContext
    @ScaledMetric(relativeTo: .body) private var scaledCellWidth: CGFloat = 44
    private var cellWidth: CGFloat { max(44, scaledCellWidth) }
    @ScaledMetric(relativeTo: .body) private var scaledDateWidth: CGFloat = 64
    private var dateWidth: CGFloat { max(64, scaledDateWidth) }
    @State private var state = MonthlyTrackerState()
    @State private var forcedFailure = TrackerDebugFailure.requested()
    @State private var savedSinceLoad = false
    @State private var saveEvidence = "save=none"
    @State private var readEvidence = "read=none"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            Text("HABIT TRACKER")
                .font(DesignTokens.Fonts.heading)
                .accessibilityIdentifier("monthlyTrackerMonth")
                .accessibilityValue(monthKey)
            if let problem = state.problem {
                problemView(problem)
            }
            if state.monthKey == monthKey, let content = state.content {
                if content.columns.isEmpty {
                    Text("この月の習慣はありません")
                        .font(DesignTokens.Fonts.bodyText)
                        .accessibilityIdentifier("monthlyTrackerEmpty")
                    Spacer()
                } else {
                    grid(content)
                }
            } else if state.problem == nil {
                ProgressView("習慣を読み込み中")
                Spacer()
            } else {
                Spacer()
            }
        }
        .foregroundStyle(DesignTokens.ink)
        .padding(.horizontal, DesignTokens.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            #if DEBUG
            if TrackerDebugFailure.diagnosticsEnabled {
                Text(saveEvidence + " | " + readEvidence)
                    .font(.caption2)
                    .frame(width: 1, height: 1)
                    .clipped()
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("trackerOperationEvidence")
            }
            #endif
        }
        .onAppear { state.load(monthKey: monthKey, read: readContent) }
        .onChange(of: monthKey) { _, key in state.load(monthKey: key, read: readContent) }
    }

    private func problemView(_ problem: MonthlyTrackerState.Problem) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            Text(problemMessage(problem))
                .font(DesignTokens.Fonts.bodyText)
                .accessibilityIdentifier("monthlyTrackerError")
            Button("再試行") {
                state.retry(todayKey: todayKey, write: writeCheck, read: readContent)
            }
            .buttonStyle(.bordered)
            .tint(DesignTokens.accent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("monthlyTrackerRetry")
        }
    }

    private func problemMessage(_ problem: MonthlyTrackerState.Problem) -> String {
        switch problem {
        case .read: return "習慣を読み込めませんでした"
        case .save: return "チェックを保存できませんでした"
        case .savedButReloadFailed: return "チェックは保存しましたが、再読み込みできませんでした"
        }
    }

    private func grid(_ content: MonthlyTrackerContent) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("日付").frame(width: dateWidth, alignment: .leading)
                        ForEach(content.columns) { column in
                            Text(column.shortLabel.isEmpty ? column.name : column.shortLabel)
                                .frame(width: cellWidth, alignment: .center)
                                .accessibilityLabel(column.name)
                        }
                    }
                    .font(DesignTokens.Fonts.subText)
                    .padding(.vertical, DesignTokens.Spacing.s)
                    ForEach(DateKey.dayKeys(inMonth: monthKey), id: \.self) { date in
                        HStack(spacing: 0) {
                            Text(dayLabel(date))
                                .font(DesignTokens.Fonts.subText)
                                .frame(width: dateWidth, alignment: .leading)
                                .frame(minHeight: cellWidth)
                                .id("trackerDay-" + date)
                            ForEach(content.columns) { column in
                                checkButton(column, date: date, content: content)
                            }
                        }
                        .background(date == todayKey ? DesignTokens.todayBand : Color.clear)
                    }
                }
            }
            .accessibilityIdentifier("monthlyTrackerGrid")
            .onAppear {
                let first = DateKey.dayKeys(inMonth: monthKey).first ?? ""
                let target = DateKey.monthKey(ofDayKey: todayKey) == monthKey ? todayKey : first
                proxy.scrollTo("trackerDay-" + target, anchor: UnitPoint(x: 0, y: 0.5))
            }
        }
    }

    private func checkButton(_ column: MonthlyTrackerContent.Column, date: String,
                             content: MonthlyTrackerContent) -> some View {
        let done = content.checks.contains(.init(habitID: column.id, dateKey: date))
        let allowed = MonthlyTrackerRules.mayToggle(dateKey: date, monthKey: monthKey, todayKey: todayKey)
        return Button {
            state.toggle(habitID: column.id, dateKey: date, todayKey: todayKey, write: writeCheck, read: readContent)
        } label: {
            Text(done ? "■" : "□")
                .font(DesignTokens.Fonts.bodyText)
                .frame(width: cellWidth)
                .frame(minHeight: cellWidth)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(allowed ? DesignTokens.accent : DesignTokens.inkSub)
        .overlay(Rectangle().stroke(DesignTokens.grid, lineWidth: 0.5).allowsHitTesting(false))
        .disabled(!allowed || state.problem != nil)
        .accessibilityLabel(date + " " + column.name)
        .accessibilityValue(done ? "チェック済み" : "未チェック")
        .accessibilityHint(allowed ? "タップでチェックを切り替え" : "未来の日付は変更できません")
        .accessibilityIdentifier("trackerCell-" + column.id.uuidString + "-" + date)
    }

    private func dayLabel(_ date: String) -> String {
        let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
        let weekday = DateKey.weekday(ofDayKey: date).map { weekdays[$0.rawValue - 1] } ?? ""
        return String(Int(date.suffix(2)) ?? 0) + " " + weekday
    }

    private func readContent(_ key: String) throws -> MonthlyTrackerContent {
        if forcedFailure == "read" || (forcedFailure == "reload" && savedSinceLoad) {
            forcedFailure = nil
            throw TrackerDebugFailure.forced
        }
        do {
            let content = try JournalStore(context: modelContext).monthlyTrackerContent(monthKey: key)
            if TrackerDebugFailure.diagnosticsEnabled {
                let checks = content.checks.map { $0.habitID.uuidString + ":" + $0.dateKey }.sorted().joined(separator: ",")
                readEvidence = "read=success month=" + key + " checks=" + checks
            }
            savedSinceLoad = false
            return content
        } catch {
            if TrackerDebugFailure.diagnosticsEnabled { readEvidence = "read=failure month=" + key + " " + error.localizedDescription }
            throw error
        }
    }

    private func writeCheck(_ habitID: UUID, _ date: String) throws -> Bool {
        if forcedFailure == "save" {
            forcedFailure = nil
            throw TrackerDebugFailure.forced
        }
        do {
            let done = try JournalStore(context: modelContext).toggleHabit(habitID: habitID, dateKey: date)
            if TrackerDebugFailure.diagnosticsEnabled {
                saveEvidence = "save=success habit=\(habitID) date=\(date) done=\(done)"
            }
            savedSinceLoad = true
            return done
        } catch {
            if TrackerDebugFailure.diagnosticsEnabled { saveEvidence = "save=failure " + error.localizedDescription }
            throw error
        }
    }
}

/// 既存の月移動テストと同様、明示引数・Debug・メモリ内ストアだけで1回失敗させる。
enum TrackerDebugFailure: Error {
    case forced
    static var diagnosticsEnabled: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-inMemoryStore") && arguments.contains("-trackerDiagnostics")
        #else
        return false
        #endif
    }
    static func requested() -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-inMemoryStore"),
              let index = arguments.firstIndex(of: "-failTracker"),
              index + 1 < arguments.count else { return nil }
        let mode = arguments[index + 1]
        return ["read", "save", "reload"].contains(mode) ? mode : nil
        #else
        return nil
        #endif
    }
}
