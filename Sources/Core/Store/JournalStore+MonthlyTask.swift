import Foundation

extension JournalStore {
    /// その月の Monthly Task。読むだけ。何も作らない・保存しない。
    ///
    /// 同じ月の月ページが複数あっても、全部から集める。1枚だけにしない。
    /// 同じタスク id は1件にする。並びで先になる方を残す。
    /// 出すのは scope が monthly のものだけ。
    /// 並びは sortOrder、同じなら作った時刻、それも同じなら id の文字順。
    /// 月ページが無いとき、月キーが不正なときは、空を返す。ページは作らない。
    /// 日のタスクや、別の月のタスクは入れない。
    func monthlyTasks(monthKey: String) throws -> [JournalTask] {
        guard DateKey.isValidMonthKey(monthKey) else {
            return []
        }
        let indexPages = try monthlyIndexPages(inMonth: monthKey)
        var gathered: [UUID: JournalTask] = [:]
        for indexPage in indexPages {
            guard let monthly = indexPage.monthly else {
                continue
            }
            let linked = try tasks(onMonthly: monthly)
            for task in linked {
                guard task.scope == .monthly else {
                    continue
                }
                if let existing = gathered[task.id] {
                    gathered[task.id] = earlierTask(existing, task)
                } else {
                    gathered[task.id] = task
                }
            }
        }
        return sortedMonthlyTasks(Array(gathered.values))
    }

    /// 同じ id が複数あるとき、一覧で先に来る方を残す。
    private func earlierTask(_ lhs: JournalTask, _ rhs: JournalTask) -> JournalTask {
        if lhs.sortOrder != rhs.sortOrder {
            if lhs.sortOrder < rhs.sortOrder {
                return lhs
            }
            return rhs
        }
        if lhs.createdAt != rhs.createdAt {
            if lhs.createdAt < rhs.createdAt {
                return lhs
            }
            return rhs
        }
        return lhs
    }

    /// sortOrder、作った時刻、id の文字順。小さい方を先にする。
    private func sortedMonthlyTasks(_ items: [JournalTask]) -> [JournalTask] {
        items.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
