import Foundation
import SwiftData

/// ページ同士のつながり（日のページから月のページ、繰り越し、など）。
///
/// どのページかは、関係（リレーション）にしない。`fromPageID` と `toPageID`（UUID）だけ持つ。
/// ページを消しても、このつながりレコードの消し方は、あとで保存係が決める（T-105、T-108）。
/// ユニーク制約（同じ値を禁止する印）は付けない。
@Model
final class PageLink {
    /// つながり1件を見分ける ID。
    var id: UUID = UUID()
    /// つながりの元ページの ID。関係にはしない。
    var fromPageID: UUID = UUID()
    /// つながりの先ページの ID。関係にはしない。
    var toPageID: UUID = UUID()
    /// 種類の文字列。`dailyToMonthly` / `carryOver`。知らない文字のときは `dailyToMonthly` に戻す。
    var typeRaw: String = PageLinkType.dailyToMonthly.rawValue
    /// 作った時刻。
    var createdAt: Date = Date.now

    /// 保存されない種類。
    var type: PageLinkType {
        get { PageLinkType(rawValue: typeRaw) ?? .dailyToMonthly }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        fromPageID: UUID = UUID(),
        toPageID: UUID = UUID(),
        typeRaw: String = PageLinkType.dailyToMonthly.rawValue,
        createdAt: Date = Date.now
    ) {
        self.id = id
        self.fromPageID = fromPageID
        self.toPageID = toPageID
        self.typeRaw = typeRaw
        self.createdAt = createdAt
    }
}
