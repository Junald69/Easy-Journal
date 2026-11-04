import SwiftData
import SwiftUI

/// 月の左ページ（Monthly Log）。
///
/// 文章の部分だけ、その場で1行を編集できる。保存は `setLogLine` だけ。
/// 文章がある行を空にして確定するときは、消す前に確認する。
/// 日付の数字と曜日は、この画面では何もしない。
/// 上のボタンは、まだ動かない。押しても何もしない。
struct MonthlyLogPageView: View {
    /// 表示する月（`yyyy-MM`）。
    let monthKey: String
    /// 今日の日付キー（`yyyy-MM-dd`）。帯とスクロールに使う。
    let todayKey: String

    @Environment(\.modelContext) private var modelContext
    /// アプリが前面から離れたときに、編集中の行を確定する。
    @Environment(\.scenePhase) private var scenePhase

    /// 保存先から読んだ、その月の1行。編集中の下書きとは別。
    @State private var textByDateKey: [String: String] = [:]
    /// 中身のある Daily がある日。
    @State private var dailyDateKeys: Set<String> = []
    /// 読み出しに失敗したとき true。
    @State private var loadFailed = false
    /// 保存に失敗したとき true。成功したら false。
    @State private var saveFailed = false
    /// いま編集している日。無いときは nil。
    @State private var editingDateKey: String? = nil
    /// 編集中の文章。読み直しでは消さない。
    @State private var draftText = ""
    /// 別の行へ移している途中だけ true。
    ///
    /// 前の編集欄が消えると、フォーカスが一度空になる。
    /// その空を「外れた」と扱うと、移した先の下書きまで保存して閉じてしまう。
    /// 移し終わるまで、その空では保存しない。
    @State private var isMovingEdit = false
    /// 編集欄に、一度フォーカスが乗ったあとだけ、外れたときに保存する。
    @State private var editFocusLanded = false
    /// どの行の編集欄にフォーカスがあるか。
    @FocusState private var focusedDateKey: String?
    /// 文章がある行を空にして確定する前の、確認待ちの日。無いときは nil。
    ///
    /// アラートを出しているあいだ、フォーカスは外れる。
    /// この値が入っているあいだは、外れても保存しない。もう一度確認も出さない。
    @State private var pendingDeleteDateKey: String? = nil

    /// 今日の帯は、読み出しのあとではなく、渡された今日の日付から計算する。
    /// 日付が変わっても、開いている月はそのまま。帯だけが動く。
    private var rows: [MonthlyLogRow] {
        MonthlyLogRows.make(
            monthKey: monthKey,
            textByDateKey: textByDateKey,
            dailyDateKeys: dailyDateKeys,
            todayKey: todayKey
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            logList
            if loadFailed {
                Text("記録を読み込めませんでした")
                    .font(DesignTokens.Fonts.subText)
                    .foregroundStyle(DesignTokens.inkSub)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(DesignTokens.Spacing.s)
            }
            if saveFailed {
                Text("保存できませんでした")
                    .font(DesignTokens.Fonts.subText)
                    .foregroundStyle(DesignTokens.inkSub)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(DesignTokens.Spacing.s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            GridPaperBackground()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthlyLogScreen")
        .onAppear {
            reload()
        }
        .onChange(of: monthKey) { _, _ in
            handleMonthChange()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
        .onChange(of: focusedDateKey) { oldFocus, newFocus in
            handleFocusChange(oldFocus: oldFocus, newFocus: newFocus)
        }
        .alert(
            "この行を消しますか？",
            isPresented: pendingDeletePresented,
            presenting: pendingDeleteDateKey
        ) { dateKey in
            Button("消す", role: .destructive) {
                confirmDelete(dateKey: dateKey)
            }
            .accessibilityIdentifier("monthlyLogDeleteConfirm")
            Button("キャンセル", role: .cancel) {
                cancelDelete(dateKey: dateKey)
            }
            .accessibilityIdentifier("monthlyLogDeleteCancel")
        } message: { _ in
            EmptyView()
        }
    }

    /// 確認のアラートを出しているか。閉じたときは、待っている日を消す。
    ///
    /// ボタンの処理は、表示したときの日付を受け取る。ここで日付を消しても、消す・戻すは実行できる。
    private var pendingDeletePresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteDateKey != nil },
            set: { showsAlert in
                if showsAlert == false {
                    pendingDeleteDateKey = nil
                }
            }
        )
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

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("MONTHLY LOG")
                        .font(DesignTokens.Fonts.subText)
                        .foregroundStyle(DesignTokens.inkSub)
                        .padding(.horizontal, DesignTokens.Spacing.l)
                        .padding(.vertical, DesignTokens.Spacing.s)
                    ForEach(rows, id: \.dateKey) { row in
                        logRow(row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToToday(in: rows, proxy: proxy)
            }
            .onChange(of: editingDateKey) { _, newKey in
                if let newKey {
                    proxy.scrollTo(newKey, anchor: .top)
                }
            }
            .onChange(of: monthKey) { _, _ in
                scrollToToday(in: rows, proxy: proxy)
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
                .accessibilityHidden(true)
            Text(shortWeekday(row.weekday))
                .font(DesignTokens.Fonts.bodyText)
                .foregroundStyle(dayColor(isWeekend: row.isWeekend))
                .frame(minWidth: DesignTokens.gridSize * 2, alignment: .leading)
                .accessibilityHidden(true)
            lineControl(row)
            if row.hasDaily {
                Image(systemName: "doc.text")
                    .font(DesignTokens.Fonts.bodyText)
                    .foregroundStyle(DesignTokens.accent)
                    .accessibilityLabel("Dailyあり")
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.gridSize * 2, alignment: .leading)
        .background(row.isToday ? DesignTokens.todayBand : Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthlyLogRow-" + row.dateKey)
        .id(row.dateKey)
    }

    /// 編集中はその場の1行欄。それ以外は、文章だけを押せる。
    @ViewBuilder
    private func lineControl(_ row: MonthlyLogRow) -> some View {
        if editingDateKey == row.dateKey {
            TextField("", text: $draftText)
                .font(DesignTokens.Fonts.bodyText)
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .focused($focusedDateKey, equals: row.dateKey)
                .submitLabel(.done)
                .onSubmit {
                    commitAndClose()
                }
                .onAppear {
                    focusedDateKey = row.dateKey
                }
                .frame(maxWidth: .infinity, minHeight: DesignTokens.gridSize, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignTokens.accent)
                        .frame(height: 1)
                }
                .accessibilityLabel(editingAccessibilityLabel(for: row))
                .accessibilityIdentifier("monthlyLogText-" + row.dateKey)
        } else {
            Button {
                editRow(dateKey: row.dateKey)
            } label: {
                Text(row.text)
                    .font(DesignTokens.Fonts.bodyText)
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.gridSize, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(spokenLabel(for: row))
            .accessibilityHint("ダブルタップで文章を編集")
            .accessibilityIdentifier("monthlyLogText-" + row.dateKey)
        }
    }

    /// その日の文章を編集し始める。別の行を編集中なら、先に確定する。
    /// 確定に失敗したときは、入力を残して、その行のままにする。
    ///
    /// 今の行を空にして消すときは、確認を出して移動を止める。移動先は開かない。
    /// 確認を出しているあいだは、何もしない。
    private func editRow(dateKey: String) {
        if pendingDeleteDateKey != nil {
            return
        }
        // 読み込み失敗中は文章を空で出している。編集すると、隠れた文章を上書きする。
        guard loadFailed == false else {
            return
        }
        if editingDateKey == dateKey {
            focusedDateKey = dateKey
            return
        }
        if let current = editingDateKey {
            if draftDeletesExistingLine(dateKey: current) {
                pendingDeleteDateKey = current
                return
            }
        }
        isMovingEdit = true
        editFocusLanded = false
        if let current = editingDateKey {
            let saved = saveDraft(dateKey: current)
            if saved == false {
                isMovingEdit = false
                editFocusLanded = true
                focusedDateKey = current
                return
            }
        }
        draftText = textByDateKey[dateKey] ?? ""
        editingDateKey = dateKey
        focusedDateKey = dateKey
    }

    /// キーボードの確定。成功したら編集を閉じる。失敗したら欄に残す。
    ///
    /// 文章がある行を空にするときは、保存せず確認を出す。
    private func commitAndClose() {
        guard let current = editingDateKey else {
            return
        }
        if pendingDeleteDateKey != nil {
            return
        }
        if draftDeletesExistingLine(dateKey: current) {
            pendingDeleteDateKey = current
            return
        }
        isMovingEdit = true
        editFocusLanded = false
        let saved = saveDraft(dateKey: current)
        if saved {
            editingDateKey = nil
            draftText = ""
            focusedDateKey = nil
        } else {
            editFocusLanded = true
            focusedDateKey = current
        }
        isMovingEdit = false
    }

    /// フォーカスが外れたときだけ確定する。行を移した直後の外れは無視する。
    ///
    /// 確認を出しているあいだは、何もしない。アラート自体がフォーカスを外すため。
    /// 文章がある行を空にするときは、保存せず確認を出す。
    private func handleFocusChange(oldFocus: String?, newFocus: String?) {
        if pendingDeleteDateKey != nil {
            return
        }
        if let landed = newFocus {
            if let current = editingDateKey {
                if landed == current {
                    editFocusLanded = true
                    isMovingEdit = false
                    return
                }
            }
        }
        guard newFocus == nil else {
            return
        }
        guard let previous = oldFocus else {
            return
        }
        guard let current = editingDateKey else {
            return
        }
        guard previous == current else {
            return
        }
        guard editFocusLanded, isMovingEdit == false else {
            return
        }
        if draftDeletesExistingLine(dateKey: previous) {
            pendingDeleteDateKey = previous
            return
        }
        let saved = saveDraft(dateKey: previous)
        if saved {
            editingDateKey = nil
            draftText = ""
            editFocusLanded = false
        } else {
            focusedDateKey = previous
        }
    }

    /// 背面に回ったときだけ、編集中なら確定する。失敗しても入力は残す。
    ///
    /// `.inactive`（コントロールセンターや着信など、一時的に前面を外れた状態）では保存しない。
    /// その瞬間に下書きが空だと、その日の行が消える。
    /// 文章がある行を空にする下書きは、確認を出せないので保存しない。下書きと編集はそのまま残す。
    /// 空でない下書きは、今までどおり保存する。
    private func handleScenePhase(_ newPhase: ScenePhase) {
        guard newPhase == .background else {
            return
        }
        guard let current = editingDateKey else {
            return
        }
        if draftDeletesExistingLine(dateKey: current) {
            return
        }
        _ = saveDraft(dateKey: current)
    }

    /// 月が変わったら、編集中の行を確定してから読み直す。
    ///
    /// 文章がある行を空にする下書きは保存しない。元の文字に戻して、編集を閉じる。
    /// 空でない下書きは、今までどおり保存する。
    private func handleMonthChange() {
        if let current = editingDateKey {
            if draftDeletesExistingLine(dateKey: current) {
                cancelDelete(dateKey: current)
            } else {
                isMovingEdit = true
                editFocusLanded = false
                let saved = saveDraft(dateKey: current)
                if saved {
                    editingDateKey = nil
                    draftText = ""
                    focusedDateKey = nil
                } else {
                    editFocusLanded = true
                }
                isMovingEdit = false
            }
        }
        reload()
    }

    /// 今の下書きを確定すると、保存してある文章が消えるとき true。
    private func draftDeletesExistingLine(dateKey: String) -> Bool {
        MonthlyLogEditRule.needsDeleteConfirmation(
            original: textByDateKey[dateKey],
            draft: draftText
        )
    }

    /// 「消す」。空の文字でその日の行を消し、編集を閉じる。
    /// 失敗したときは「保存できませんでした」を出し、入力を残す。
    ///
    /// 確認待ちは、保存が終わってから外す。外したあとのフォーカス変化で、もう一度保存しない。
    private func confirmDelete(dateKey: String) {
        let saved = deleteConfirmedLine(dateKey: dateKey)
        if saved {
            editingDateKey = nil
            draftText = ""
            focusedDateKey = nil
            editFocusLanded = false
            isMovingEdit = false
        } else {
            editFocusLanded = true
            focusedDateKey = dateKey
        }
        pendingDeleteDateKey = nil
    }

    /// 「キャンセル」。元の文字に戻し、保存せずに編集を閉じる。記録は変えない。
    private func cancelDelete(dateKey: String) {
        draftText = textByDateKey[dateKey] ?? ""
        editingDateKey = nil
        focusedDateKey = nil
        editFocusLanded = false
        isMovingEdit = false
        pendingDeleteDateKey = nil
    }

    /// 確認のあと、その日の行を空にして消す。下書きの文字は、ここでは変えない。
    private func deleteConfirmedLine(dateKey: String) -> Bool {
        let store = JournalStore(context: modelContext)
        do {
            try store.setLogLine(dateKey: dateKey, text: "")
        } catch {
            saveFailed = true
            return false
        }
        saveFailed = false
        reload()
        return true
    }

    /// 下書きを保存する。入力の1文字ごとには呼ばない。
    ///
    /// 成功したら、編集中でない行の表示だけ読み直す。下書きはここでは消さない。
    /// 失敗したら false。画面の文字は捨てない。
    private func saveDraft(dateKey: String) -> Bool {
        let store = JournalStore(context: modelContext)
        do {
            try store.setLogLine(dateKey: dateKey, text: draftText)
        } catch {
            saveFailed = true
            return false
        }
        saveFailed = false
        reload()
        return true
    }

    /// 環境の読み書きの窓口から、月の行を読む。失敗してもクラッシュしない。
    /// 編集中の下書きは変えない。
    private func reload() {
        let store = JournalStore(context: modelContext)
        do {
            let content = try store.monthlyLogContent(monthKey: monthKey)
            textByDateKey = content.textByDateKey
            dailyDateKeys = content.dailyDateKeys
            loadFailed = false
        } catch {
            textByDateKey = [:]
            dailyDateKeys = []
            loadFailed = true
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

    /// 編集欄の読み上げ。どの日の欄かを含む。入力中の文字は、欄の値として残す。
    private func editingAccessibilityLabel(for row: MonthlyLogRow) -> String {
        var parts: [String] = [
            String(row.dayNumber) + "日",
            spokenWeekday(row.weekday),
            row.dateKey
        ]
        if row.isToday {
            parts.append("今日")
        }
        return parts.joined(separator: " ")
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
