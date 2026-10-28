import Foundation
import SwiftData

/// タスク。Swift 標準の `Task`（並行処理の型）と名前がぶつかるので、`JournalTask` にする。
///
/// 日のタスクなら `daily`、月のタスクなら `monthly` に属する。どちらか一方だけ。もう一方は nil。
/// 繰り越し元・繰り越し先は、関係（リレーション）にしない。UUID だけ持つ。
/// タスクを消しても、履歴（`TaskHistory`）は残すため。UUID の片付けは T-108。
/// 1日に複数あってよい。ユニーク制約（同じ値を禁止する印）は付けない。
@Model
final class JournalTask {
    /// タスクを見分ける ID。
    var id: UUID = UUID()
    /// タスクの文言。
    var title: String = ""
    /// 日か月かの文字列。`daily` / `monthly`。知らない文字のときは `daily` に戻す。
    var scopeRaw: String = TaskScope.daily.rawValue
    /// 進み具合の文字列。`open` / `partial` / `done`。知らない文字のときは `open` に戻す。
    var progressRaw: String = TaskProgress.open.rawValue
    /// 繰り越し済みなら true。画面では「>」の印。
    var isCarriedForward: Bool = false
    /// 繰り越し元タスクの ID。関係にはしない。
    var carriedFromTaskID: UUID? = nil
    /// 繰り越し先タスクの ID。関係にはしない。
    var carriedToTaskID: UUID? = nil
    /// 並び順。小さいほど上。
    var sortOrder: Int = 0
    /// 作った時刻。
    var createdAt: Date = Date.now
    /// 完了した時刻。未完了なら nil。
    var completedAt: Date? = nil

    /// 属している日ページ。日ページを消すと、このタスクも消える（ルールは日ページ側）。
    @Relationship
    var daily: DailyPage? = nil

    /// 属している月ページ。月ページを消すと、このタスクも消える（ルールは月ページ側）。
    @Relationship
    var monthly: MonthlyPage? = nil

    /// 保存されない範囲（日か月か）。
    var scope: TaskScope {
        get { TaskScope(rawValue: scopeRaw) ?? .daily }
        set { scopeRaw = newValue.rawValue }
    }

    /// 保存されない進み具合。
    var progress: TaskProgress {
        get { TaskProgress(rawValue: progressRaw) ?? .open }
        set { progressRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        scopeRaw: String = TaskScope.daily.rawValue,
        progressRaw: String = TaskProgress.open.rawValue,
        isCarriedForward: Bool = false,
        carriedFromTaskID: UUID? = nil,
        carriedToTaskID: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date.now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.scopeRaw = scopeRaw
        self.progressRaw = progressRaw
        self.isCarriedForward = isCarriedForward
        self.carriedFromTaskID = carriedFromTaskID
        self.carriedToTaskID = carriedToTaskID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
