import Foundation

/// 「今日」の日付キーを決める。画面は持たない。保存しない。
///
/// 固定値を使うのは、Debug ビルドかつメモリ上の保存先で、日付キーとして読めるときだけ。
/// それ以外は `DateKey.todayKey`。Debug かどうかは、呼び出し側が Bool で渡す。
enum TodayKeyResolver {
    /// 今日の日付キー。
    ///
    /// `fixedDayKey` は、起動引数などで固定したい日付。無ければ nil。
    /// `inMemoryStore` は、メモリ上の保存先のとき true。
    /// `isDebugBuild` は、Debug ビルドのとき true。Release では false。
    /// `now` はそのときの時計。`calendar` はそのとき使う暦。
    static func resolve(
        fixedDayKey: String?,
        inMemoryStore: Bool,
        isDebugBuild: Bool,
        now: Date,
        calendar: Calendar
    ) -> String {
        let usual = DateKey.todayKey(now: now, calendar: calendar)
        if isDebugBuild,
           inMemoryStore,
           let requested = fixedDayKey,
           DateKey.isValidDayKey(requested) {
            return requested
        }
        return usual
    }
}
