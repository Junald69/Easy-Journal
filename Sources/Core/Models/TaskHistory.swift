import Foundation
import SwiftData

/// タスクの変化の履歴。追記だけする（書き換えない）想定。中身のルールは T-107。
///
/// タスクを消しても、履歴は残す。そのため `taskID` と `relatedTaskID` は関係（リレーション）にしない。
/// UUID の項目だけにする。
/// ユニーク制約（同じ値を禁止する印）は付けない。
@Model
final class TaskHistory {
    /// 履歴1件を見分ける ID。
    var id: UUID = UUID()
    /// 対象タスクの ID。関係にはしない。
    var taskID: UUID = UUID()
    /// 何が起きたかの文字列。知らない文字のときは、計算プロパティが `created` に戻す。
    var actionRaw: String = TaskHistoryAction.created.rawValue
    /// 変わる前の進み具合の文字列。無いときは nil。知らない文字のときは、計算プロパティは nil を返す（落ちない）。
    var fromProgressRaw: String? = nil
    /// 変わった後の進み具合の文字列。無いときは nil。知らない文字のときは nil を返す（落ちない）。
    var toProgressRaw: String? = nil
    /// 繰り越し先や元のタスク ID。関係にはしない。
    var relatedTaskID: UUID? = nil
    /// 繰り越し先の日付など（例：`2026-10-28`）。
    var relatedDateKey: String? = nil
    /// この履歴が起きた時刻。
    var at: Date = Date.now

    /// 保存されない「何が起きたか」。
    var action: TaskHistoryAction {
        get { TaskHistoryAction(rawValue: actionRaw) ?? .created }
        set { actionRaw = newValue.rawValue }
    }

    /// 保存されない、変わる前の進み具合。文字列が空、または知らない文字なら nil。
    var fromProgress: TaskProgress? {
        get {
            guard let fromProgressRaw else { return nil }
            return TaskProgress(rawValue: fromProgressRaw)
        }
        set { fromProgressRaw = newValue?.rawValue }
    }

    /// 保存されない、変わった後の進み具合。文字列が空、または知らない文字なら nil。
    var toProgress: TaskProgress? {
        get {
            guard let toProgressRaw else { return nil }
            return TaskProgress(rawValue: toProgressRaw)
        }
        set { toProgressRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        taskID: UUID = UUID(),
        actionRaw: String = TaskHistoryAction.created.rawValue,
        fromProgressRaw: String? = nil,
        toProgressRaw: String? = nil,
        relatedTaskID: UUID? = nil,
        relatedDateKey: String? = nil,
        at: Date = Date.now
    ) {
        self.id = id
        self.taskID = taskID
        self.actionRaw = actionRaw
        self.fromProgressRaw = fromProgressRaw
        self.toProgressRaw = toProgressRaw
        self.relatedTaskID = relatedTaskID
        self.relatedDateKey = relatedDateKey
        self.at = at
    }
}
