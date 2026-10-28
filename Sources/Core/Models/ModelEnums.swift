import Foundation

/// 選択肢（enum）。
///
/// モデルには、この enum 自体ではなく、文字列（`rawValue`）を保存する。
/// モデル側の項目名は `kindRaw` のように `Raw` で終わる。
/// 画面や処理で使うときは、モデルの計算プロパティ（保存されない項目）が enum に戻す。
///
/// 文字列で持つ理由：あとで検索条件（`#Predicate`）に使うとき、
/// enum そのものを保存すると不具合が出ることがある、と言われているため。
/// この理由が実際に正しいかは未確認。安全側に倒している。
/// 保存の形を後から変えると、データの引っ越しが必要になる。

/// ページの種類。保存する文字列は `daily` / `monthly`。
enum PageKind: String {
    /// その日のページ。
    case daily
    /// 月のページ。
    case monthly
}

/// タスクの進み具合。保存する文字列は `open` / `partial` / `done`。
enum TaskProgress: String {
    /// 未完了。
    case open
    /// 一部だけ進んだ。
    case partial
    /// 完了。
    case done
}

/// タスクが日のものか、月のものか。保存する文字列は `daily` / `monthly`。
enum TaskScope: String {
    case daily
    case monthly
}

/// ページを誰が作ったか。保存する文字列は `user` / `carryOver` / `system`。
enum PageCreatedBy: String {
    /// 人が作った。
    case user
    /// 繰り越しで作った。
    case carryOver
    /// アプリが作った。
    case system
}

/// 紙の模様。保存する文字列は `grid` / `lined` / `plain`。
enum PaperStyle: String {
    /// 方眼。
    case grid
    /// 横線。
    case lined
    /// 無地。
    case plain
}

/// 紙の地の色。保存する文字列は `white` / `offWhite` / `black`。
enum PaperBackground: String {
    case white
    /// オフホワイト（少し黄みがかった白）。
    case offWhite
    case black
}

/// タスクの履歴で、何が起きたか。
/// 保存する文字列は、ケース名と同じ（例：`created`、`progressChanged`）。
enum TaskHistoryAction: String {
    /// 作った。
    case created
    /// 進み具合が変わった。
    case progressChanged
    /// 翌日へ繰り越した。
    case carriedForward
    /// 繰り越しを取り消した。
    case carryCancelled
    /// 内容を直した。
    case edited
    /// 消した。
    case deleted
}

/// ページ同士のつながりの種類。
/// 保存する文字列は `dailyToMonthly` / `carryOver`。
enum PageLinkType: String {
    /// 日のページから、その月のページへ。
    case dailyToMonthly
    /// 繰り越し元の日のページから、繰り越し先の日のページへ。
    case carryOver
}
