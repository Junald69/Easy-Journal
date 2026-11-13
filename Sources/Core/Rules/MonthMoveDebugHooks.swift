import Foundation

/// 画面テストが、月の移動の失敗を1回だけ起こすための印。保存しない。
///
/// Debug ビルドかつメモリ上の保存先のときだけ有効。Release では無視する。
/// 失敗させるために、記録を作ったり消したりはしない。
enum MonthMoveFailureInjection: Equatable {
    /// 移る先の月ページの保存に失敗したことにする。
    case save
    /// 移る先の読み込みに失敗したことにする。
    case load
    /// 一言日記の保存を、`setLogLine` の保存で1回失敗させる。
    case log

    /// 起動引数の文字列から読む。条件を満たさないときは nil。
    static func fromLaunchArgument(
        _ argument: String?,
        inMemoryStore: Bool,
        isDebugBuild: Bool
    ) -> MonthMoveFailureInjection? {
        guard isDebugBuild, inMemoryStore, let argument else {
            return nil
        }
        switch argument {
        case "save":
            return .save
        case "load":
            return .load
        case "log":
            return .log
        default:
            return nil
        }
    }
}

/// 画面テストが、一言日記の保存だけを失敗させるときに `JournalStore` へ渡すエラー。
///
/// 記録は作らない。成功した保存の代わりには使わない。
enum MonthMoveDebugSaveError: Error {
    case forced
}

/// 画面テストが、◀▶ を通さずに月を開く依頼を出すための印。
///
/// Debug ビルドかつメモリ上の保存先で、月キーとして読めるときだけ返す。
enum MonthMoveDebugJump {
    static func monthKey(
        argument: String?,
        inMemoryStore: Bool,
        isDebugBuild: Bool
    ) -> String? {
        guard isDebugBuild, inMemoryStore, let argument else {
            return nil
        }
        guard DateKey.isValidMonthKey(argument) else {
            return nil
        }
        return argument
    }
}

/// 画面テストが、月の画面を出ているあいだに URL を開くための印。
///
/// Debug ビルドかつメモリ上の保存先で、`easyjournal://` で始まるときだけ返す。
/// ページは、ここでは変えない。開くときは Router の確認を通す。
enum MonthMoveDebugOpen {
    static func url(
        argument: String?,
        inMemoryStore: Bool,
        isDebugBuild: Bool
    ) -> URL? {
        guard isDebugBuild, inMemoryStore, let argument else {
            return nil
        }
        guard argument.hasPrefix("easyjournal://") else {
            return nil
        }
        return URL(string: argument)
    }
}
