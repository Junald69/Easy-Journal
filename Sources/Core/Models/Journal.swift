import Foundation
import SwiftData

/// 手帳そのもの。MVP（最初の公開版）では 1 冊だけ使う想定。
///
/// ページ（`Page`）の親。ページを消すルールは、こちら側の関係に書いてある（cascade。親を消すと子も消える）。
/// ユニーク制約（同じ値を2つ禁止する印）は付けない。将来の同期で使えないため。
@Model
final class Journal {
    /// 手帳を見分ける ID。
    var id: UUID = UUID()
    /// 表紙のタイトル。
    var title: String = "My Journal"
    /// 週の始まりを月曜にするか。true なら月曜始まり。
    var weekStartsOnMonday: Bool = true
    /// この手帳を作った時刻。
    var createdAt: Date = Date.now

    /// この手帳のページ一覧。
    /// 手帳を消すと、ページも消える。
    /// inverse（反対側の項目）は、ペアの片方だけに書く。
    @Relationship(deleteRule: .cascade, inverse: \Page.journal)
    var pages: [Page]? = []

    init(
        id: UUID = UUID(),
        title: String = "My Journal",
        weekStartsOnMonday: Bool = true,
        createdAt: Date = Date.now
    ) {
        self.id = id
        self.title = title
        self.weekStartsOnMonday = weekStartsOnMonday
        self.createdAt = createdAt
    }
}
