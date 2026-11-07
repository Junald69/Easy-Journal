import SwiftData
import SwiftUI

/// 月の左ページ（Monthly Log と Monthly Task）。
///
/// 1行の文章は、まだ読むだけ。上のボタンは、まだ動かない。押しても何もしない。
/// タスクの追加・状態・削除は、JournalStore だけを通す。画面から直接は足さない。
/// 翌月への繰越、タイトルの編集、並べ替え、履歴の画面は、ここでは作らない。
struct MonthlyLogPageView: View {
    /// 表示する月（`yyyy-MM`）。
    let monthKey: String
    /// 今日の日付キー（`yyyy-MM-dd`）。帯とスクロールに使う。
    let todayKey: String

    @Environment(\.modelContext) private var modelContext
    /// 保存のあとに、一覧を読み直すための番号。
    @State private var revision = 0
    /// ＋ のあと、タイトル欄を出しているか。
    @State private var isAdding = false
    /// 追加しようとしているタイトル。失敗しても捨てない。
    @State private var draftTitle = ""
    /// 削除の確認で、対象にしているタスク。キャンセルでは nil に戻すだけ。
    @State private var deleteTarget: DeleteTarget?
    /// 保存できなかったときの一文。読み込みの失敗とは別に持つ。
    @State private var saveNotice: String?

    var body: some View {
        let snapshot = load(revision: revision)
        loadedBody(snapshot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                GridPaperBackground()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("monthlyLogScreen")
            .alert(
                "タスクを消しますか",
                isPresented: deletePresented,
                presenting: deleteTarget
            ) { target in
                Button("消す") {
                    let taskID = target.id
                    performDelete(id: taskID)
                }
                Button("キャンセル", role: .cancel) {}
            } message: { target in
                Text(target.title)
            }
    }

    /// 確認アラートの開閉。閉じたときは対象を空に戻す。データは変えない。
    private var deletePresented: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { isPresented in
                if isPresented == false {
                    deleteTarget = nil
                }
            }
        )
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
                    MonthlyTaskSection(
                        tasks: snapshot.tasks,
                        interactionsEnabled: snapshot.failed == false,
                        isAdding: $isAdding,
                        draftTitle: $draftTitle,
                        saveNotice: snapshot.failed ? nil : saveNotice,
                        onConfirm: {
                            confirmAdd(enabled: snapshot.failed == false)
                        },
                        onCycle: { taskID in
                            cycle(taskID: taskID, enabled: snapshot.failed == false)
                        },
                        onRequestDelete: { item in
                            guard snapshot.failed == false else { return }
                            deleteTarget = DeleteTarget(id: item.id, title: item.title)
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToToday(in: snapshot.rows, proxy: proxy)
            }
            .onChange(of: isAdding) { _, adding in
                if adding {
                    proxy.scrollTo("monthlyTaskComposer", anchor: .center)
                }
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

    /// 環境の読み書きの窓口から、月の行と月のタスクを読む。失敗してもクラッシュしない。
    ///
    /// `revision` は、保存のあとに読み直すための番号。0 未満は失敗として空を返す。
    private func load(revision: Int) -> MonthlyLogSnapshot {
        if revision < 0 {
            return MonthlyLogSnapshot(rows: [], tasks: [], failed: true)
        }
        let store = JournalStore(context: modelContext)
        do {
            let content = try store.monthlyLogContent(monthKey: monthKey)
            let rows = MonthlyLogRows.make(
                monthKey: monthKey,
                textByDateKey: content.textByDateKey,
                dailyDateKeys: content.dailyDateKeys,
                todayKey: todayKey
            )
            let storedTasks = try store.monthlyTasks(monthKey: monthKey)
            let tasks = storedTasks.map { task in
                MonthlyTaskItem(task: task)
            }
            return MonthlyLogSnapshot(rows: rows, tasks: tasks, failed: false)
        } catch {
            return MonthlyLogSnapshot(rows: [], tasks: [], failed: true)
        }
    }

    /// 読み直せたか。失敗したときは、追加も状態変更も削除もしない。
    private func canRead() -> Bool {
        let store = JournalStore(context: modelContext)
        do {
            _ = try store.monthlyLogContent(monthKey: monthKey)
            _ = try store.monthlyTasks(monthKey: monthKey)
            return true
        } catch {
            return false
        }
    }

    /// タイトルを確定して、月のタスクを1件足す。空白だけなら足さない。入力は残す。
    private func confirmAdd(enabled: Bool) {
        guard enabled else { return }
        guard canRead() else {
            revision += 1
            return
        }
        let store = JournalStore(context: modelContext)
        do {
            _ = try store.addMonthlyTask(monthKey: monthKey, title: draftTitle)
            draftTitle = ""
            isAdding = false
            saveNotice = nil
            revision += 1
        } catch let storeError as JournalStoreError {
            if storeError == .emptyTitle {
                return
            }
            saveNotice = "保存できませんでした"
            revision += 1
        } catch {
            saveNotice = "保存できませんでした"
            revision += 1
        }
    }

    /// 記号を1回進める。進み具合は JournalStore.cycleProgress だけが変える。
    ///
    /// その中で TaskRules.nextProgress が使われる。画面では進み具合を直接書かない。
    private func cycle(taskID: UUID, enabled: Bool) {
        guard enabled else { return }
        guard canRead() else {
            revision += 1
            return
        }
        let store = JournalStore(context: modelContext)
        do {
            _ = try store.cycleProgress(taskID: taskID)
            saveNotice = nil
            revision += 1
        } catch {
            saveNotice = "保存できませんでした"
            revision += 1
        }
    }

    /// 確認の「消す」のあとだけ、タスクを消す。
    private func performDelete(id: UUID) {
        guard canRead() else {
            revision += 1
            return
        }
        let store = JournalStore(context: modelContext)
        do {
            try store.deleteTask(taskID: id)
            saveNotice = nil
            revision += 1
        } catch {
            saveNotice = "保存できませんでした"
            revision += 1
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

/// 削除の確認が持っている対象。キャンセルでは、これを空に戻すだけ。
private struct DeleteTarget: Identifiable {
    let id: UUID
    let title: String
}

/// 読み出しの結果。画面の中だけで使う。
private struct MonthlyLogSnapshot {
    var rows: [MonthlyLogRow]
    var tasks: [MonthlyTaskItem]
    var failed: Bool
}
