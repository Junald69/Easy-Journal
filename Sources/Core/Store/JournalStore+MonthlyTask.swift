import Foundation

extension JournalStore {
    /// その月の Monthly Task。読むだけ。何も作らない・保存しない。
    ///
    /// 出すのは、scope が monthly で、その月ページに属するものだけ。
    /// 並びは sortOrder、同じなら作った時刻、それも同じなら id の文字順。
    /// この最後の並びは、`tasks(onMonthly:)` がもともと持っている決め方。
    /// 月ページが無いとき、月キーが不正なときは、空を返す。ページは作らない。
    /// 日のタスクや、別の月のタスクは入れない。
    func monthlyTasks(monthKey: String) throws -> [JournalTask] {
        guard DateKey.isValidMonthKey(monthKey) else {
            return []
        }
        guard let page = try findMonthly(monthKey: monthKey) else {
            return []
        }
        let linked = try tasks(onMonthly: page)
        return linked.filter { task in
            task.scope == .monthly
        }
    }
}
