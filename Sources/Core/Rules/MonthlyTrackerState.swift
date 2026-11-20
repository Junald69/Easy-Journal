import Foundation

/// 保存と再読込は別の結果。保存後の読取失敗では再試行で toggle を繰り返さない。
struct MonthlyTrackerState {
    enum Problem: Equatable { case read, save, savedButReloadFailed }
    private(set) var monthKey = ""
    private(set) var content: MonthlyTrackerContent?
    private(set) var problem: Problem?
    private var pending: MonthlyTrackerContent.Check?

    mutating func load(monthKey: String, read: (String) throws -> MonthlyTrackerContent) {
        let saved = self.monthKey == monthKey && problem == .savedButReloadFailed
        self.monthKey = monthKey
        pending = nil
        do {
            content = try read(monthKey)
            problem = nil
        } catch {
            content = nil
            problem = saved ? .savedButReloadFailed : .read
        }
    }

    mutating func toggle(habitID: UUID, dateKey: String, todayKey: String,
                         write: (UUID, String) throws -> Bool,
                         read: (String) throws -> MonthlyTrackerContent) {
        guard let content, content.columns.contains(where: { $0.id == habitID }),
              MonthlyTrackerRules.mayToggle(dateKey: dateKey, monthKey: monthKey, todayKey: todayKey) else { return }
        do {
            _ = try write(habitID, dateKey)
        } catch {
            pending = .init(habitID: habitID, dateKey: dateKey)
            problem = .save
            return
        }
        pending = nil
        // 読取に失敗した時点で古いチェック表示を取り下げる。
        problem = .savedButReloadFailed
        load(monthKey: monthKey, read: read)
    }

    mutating func retry(todayKey: String, write: (UUID, String) throws -> Bool,
                        read: (String) throws -> MonthlyTrackerContent) {
        if problem == .save, let pending,
           MonthlyTrackerRules.mayToggle(dateKey: pending.dateKey, monthKey: monthKey, todayKey: todayKey) {
            toggle(habitID: pending.habitID, dateKey: pending.dateKey, todayKey: todayKey, write: write, read: read)
        } else {
            load(monthKey: monthKey, read: read)
        }
    }
}
