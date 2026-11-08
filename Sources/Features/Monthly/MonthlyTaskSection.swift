import SwiftData
import SwiftUI

/// 月の左ページで、どの入力欄にフォーカスがあるか。
///
/// 1行とタスクの名前は、別の値にする。名前欄へ移っただけでは、1行の保存や確認は出さない。
enum MonthlyEditorFocus: Hashable {
    /// その日の1行。
    case log(String)
    /// 月のタスクの名前。
    case taskTitle
}

/// 月の左ページに出す、1件の Monthly Task。画面の中だけで使う。
struct MonthlyTaskItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    /// 画面の記号。□ / ◧ / ■。
    let symbol: String
    /// 読み上げる進み具合。「未完」「一部」「完了」。
    let spokenProgress: String

    init(task: JournalTask) {
        id = task.id
        title = task.title
        symbol = MonthlyTaskItem.symbol(for: task.progress)
        spokenProgress = MonthlyTaskItem.spokenProgress(for: task.progress)
    }

    /// 月のタスクの記号。繰越の「>」は出さない（翌月への繰越は Phase 2）。
    ///
    /// 進み具合が完了かつ繰越済みでも、落ちずに ■ を返す。
    static func symbol(for progress: TaskProgress) -> String {
        switch progress {
        case .open:
            return TaskRules.Symbol.open.text
        case .partial:
            return TaskRules.Symbol.partial.text
        case .done:
            return TaskRules.Symbol.done.text
        }
    }

    /// 記号ボタンの読み上げ。タイトルは呼び出し側で続ける。
    static func spokenProgress(for progress: TaskProgress) -> String {
        switch progress {
        case .open:
            return "未完"
        case .partial:
            return "一部"
        case .done:
            return "完了"
        }
    }
}

/// 左ページ下部の MONTHLY TASK。追加・記号・削除の見た目だけ。保存は呼び出し側。
struct MonthlyTaskSection: View {
    let tasks: [MonthlyTaskItem]
    /// 読み込みに失敗しているときは、追加・状態変更・削除を出さない。
    let interactionsEnabled: Bool
    @Binding var isAdding: Bool
    @Binding var draftTitle: String
    var editorFocus: FocusState<MonthlyEditorFocus?>.Binding
    /// 1行を編集中なら true。名前欄は、そのあいだ直接フォーカスを取らない。
    let logEditActive: Bool
    let onBeginAdd: () -> Void
    /// 編集中に名前欄を押したとき。確定してからフォーカスを移す。
    let onActivateComposer: () -> Void
    let onConfirm: () -> Void
    let onCycle: (UUID) -> Void
    let onRequestDelete: (MonthlyTaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isAdding {
                composer
            }
            ForEach(tasks) { item in
                MonthlyTaskRow(
                    item: item,
                    interactionsEnabled: interactionsEnabled,
                    onCycle: { onCycle(item.id) },
                    onRequestDelete: { onRequestDelete(item) }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthlyTaskSection")
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            Text("MONTHLY TASK")
                .font(DesignTokens.Fonts.subText)
                .foregroundStyle(DesignTokens.inkSub)
                .accessibilityLabel("月のタスク")
            Spacer(minLength: DesignTokens.Spacing.s)
            if interactionsEnabled {
                Button(action: onBeginAdd) {
                    Text("＋")
                        .font(DesignTokens.Fonts.bodyText)
                        .foregroundStyle(DesignTokens.accent)
                        .frame(minWidth: DesignTokens.gridSize * 2, minHeight: DesignTokens.gridSize * 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タスクを追加")
                .accessibilityIdentifier("monthlyTaskAddButton")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.top, DesignTokens.Spacing.l)
        .padding(.bottom, DesignTokens.Spacing.s)
    }

    private var composer: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: DesignTokens.Spacing.s) {
                TextField("タスク", text: $draftTitle)
                    .font(DesignTokens.Fonts.bodyText)
                    .foregroundStyle(DesignTokens.ink)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused(editorFocus, equals: .taskTitle)
                    .disabled(logEditActive)
                    .onSubmit { onConfirm() }
                    .onAppear {
                        if logEditActive == false {
                            editorFocus.wrappedValue = .taskTitle
                        }
                    }
                    .accessibilityIdentifier("monthlyTaskTitleField")
                Button("追加", action: onConfirm)
                    .buttonStyle(.bordered)
                    .tint(DesignTokens.accent)
                    .disabled(interactionsEnabled == false)
                    .accessibilityIdentifier("monthlyTaskConfirmButton")
            }
            if logEditActive {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onActivateComposer)
                    .accessibilityIdentifier("monthlyTaskComposerGuard")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.bottom, DesignTokens.Spacing.s)
        .id("monthlyTaskComposer")
    }
}

/// タスク1行。記号だけが状態を変える。長押しは削除のメニュー。
private struct MonthlyTaskRow: View {
    let item: MonthlyTaskItem
    let interactionsEnabled: Bool
    let onCycle: () -> Void
    let onRequestDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.s) {
            Button(action: onCycle) {
                Text(item.symbol)
                    .font(DesignTokens.Fonts.bodyText)
                    .foregroundStyle(DesignTokens.ink)
                    .frame(minWidth: DesignTokens.gridSize * 2, minHeight: DesignTokens.gridSize * 2)
            }
            .buttonStyle(.plain)
            .disabled(interactionsEnabled == false)
            .accessibilityLabel(item.spokenProgress + " " + item.title)
            .accessibilityIdentifier("monthlyTaskSymbol-" + item.id.uuidString)
            .monthlyTaskDeleteMenu(enabled: interactionsEnabled, action: onRequestDelete)
            Text(item.title)
                .font(DesignTokens.Fonts.bodyText)
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("monthlyTaskLabel-" + item.title)
                .monthlyTaskDeleteMenu(enabled: interactionsEnabled, action: onRequestDelete)
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.gridSize * 2, alignment: .leading)
        .accessibilityIdentifier("monthlyTaskRow-" + item.id.uuidString)
    }
}

private extension View {
    /// 読み込みできているときだけ、長押しの「削除」を出す。
    @ViewBuilder
    func monthlyTaskDeleteMenu(enabled: Bool, action: @escaping () -> Void) -> some View {
        if enabled {
            contextMenu {
                Button("削除", action: action)
                    .accessibilityIdentifier("monthlyTaskDeleteAction")
            }
        } else {
            self
        }
    }
}
