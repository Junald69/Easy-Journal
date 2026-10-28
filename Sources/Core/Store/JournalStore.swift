import Foundation
import SwiftData

/// ページを探す／作る保存係。日ごとの記録、タスクの追加・変更・削除、繰越もここを通す。
///
/// 画面から直接 insert（保存場所へ追加）せず、ここを通す。
/// 同じ端末の通常の使い方では、1日1枚、1か月1枚をここで守る。同じ日付がすでにあれば、新しくは作らない。
/// ページの重複は、中身があるものを優先し、その中で一番古いものを使う。ページの重複は消さない。
/// 1行・気分・睡眠の重複は、書くとき更新時刻が一番新しいものを使う。同時刻なら id の文字順が大きい方。空にすると、その日の分を全部消す。
/// 同じ値をもう一度書いても、何もしない。
/// 習慣のチェックは、同じ組み合わせが複数あれば全部消す。
/// タスクの進み具合（`progress`）は、画面から直接書かない。必ず `cycleProgress` を使う。
/// ModelContext（読み書きの窓口）を作ったスレッドから使う前提。
/// 保存に失敗したときは、未保存の変更を取り消してから、そのエラーをそのまま投げる。握りつぶさない。`fatalError` にもしない。
final class JournalStore {
    /// 記録の読み書きに使う場所。
    private let context: ModelContext

    /// 履歴や更新時刻に使う「今」。
    ///
    /// 変化がある操作では、このクロージャを1回だけ呼ぶ。同じ値の書き込みなど、変化が無いときは呼ばない。
    private let currentDate: () -> Date

    /// 実際の保存。テストでは、失敗させるために差し替えられる。
    private let persist: (ModelContext) throws -> Void

    /// 保存の入れ物から作った context（読み書きの窓口）を渡す。
    ///
    /// `now` と `save` は省略できる。既存の `JournalStore(context:)` と `JournalStore(context:now:)` はそのまま動く。
    /// `now` を省略したときは、呼ぶたびに `Date.now` を返す。
    /// `save` を省略したときは、その context の `save()` を使う。
    init(
        context: ModelContext,
        now: @escaping () -> Date = { Date.now },
        save: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.currentDate = now
        self.persist = save
    }

    /// 手帳が1冊もなければ1冊作る。初回起動用。
    ///
    /// すでに複数あるときは、作った時刻が一番古いものを返す。消さない。
    /// 時刻が同じなら、id（識別子）の文字順が小さい方を返す。
    func ensureJournal() throws -> Journal {
        let journals = try context.fetch(FetchDescriptor<Journal>())
        if let existing = preferredJournal(among: journals) {
            return existing
        }
        let journal = Journal()
        context.insert(journal)
        try saveOrRollback()
        return journal
    }

    /// その月の中身を探す。無ければ nil。何も作らない。
    func findMonthly(monthKey: String) throws -> MonthlyPage? {
        guard let page = try preferredMonthlyPage(monthKey: monthKey) else {
            return nil
        }
        return page.monthly
    }

    /// その月の中身を探す。無ければ作る。
    ///
    /// monthKey が不正なら `invalidMonthKey` を投げる。このときは何も作らない。
    /// 目次カード（Page）だけあって中身が無いときは、新しい Page は作らず、中身だけ足す。
    func findOrCreateMonthly(monthKey: String) throws -> MonthlyPage {
        guard DateKey.isValidMonthKey(monthKey) else {
            throw JournalStoreError.invalidMonthKey(monthKey)
        }
        let page = try ensuredMonthlyPage(monthKey: monthKey)
        if let monthly = page.monthly {
            return monthly
        }
        return try attachMonthly(to: page, monthKey: monthKey)
    }

    /// その日の中身を探す。無ければ nil。何も作らない。
    func findDaily(dateKey: String) throws -> DailyPage? {
        guard let page = try preferredDailyPage(dateKey: dateKey) else {
            return nil
        }
        return page.daily
    }

    /// その日の中身を探す。無ければ作る。
    ///
    /// dateKey が不正なら `invalidDayKey` を投げる。このときは何も作らない。
    /// すでにあれば、何も作らず、それを返す。`createdBy`（誰が作ったか）は変えない。
    /// 無いときは、その月の月ページも用意し、日ページから月ページへの PageLink を1つ作る。
    /// 目次カードだけあって中身が無いときは、新しい Page は作らず、中身だけ足す。
    /// その直しでは、月への PageLink と Journal（手帳）は戻さない。つながりが必ずあるとは限らない。
    func findOrCreateDaily(dateKey: String, createdBy: PageCreatedBy) throws -> DailyPage {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        guard let monthKey = DateKey.monthKey(ofDayKey: dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        if let existing = try preferredDailyPage(dateKey: dateKey) {
            if let daily = existing.daily {
                return daily
            }
            return try attachDaily(to: existing, dateKey: dateKey)
        }
        let monthlyIndex = try ensuredMonthlyPage(monthKey: monthKey)
        return try insertDaily(
            dateKey: dateKey,
            monthKey: monthKey,
            createdBy: createdBy,
            monthlyIndex: monthlyIndex
        )
    }

    // MARK: - 探す

    /// 種類が一致する目次カードを取る。
    ///
    /// 検索条件（`#Predicate`）は、種類の文字列（kindRaw）だけにしている。
    /// 既存の保存テストと同じ、文字列の一致。
    /// dateKey は空を許す文字列（String?）なので、取ったあと普通の Swift で比べる。
    /// kindRaw と dateKey を `#Predicate` の中で同時に書く書き方は、ここでは未確認。
    private func fetchPages(kindRaw: String) throws -> [Page] {
        let storedKindRaw = kindRaw
        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.kindRaw == storedKindRaw
            }
        )
        return try context.fetch(descriptor)
    }

    /// その日の目次カード。複数あれば、中身があるものの中で一番古いもの。無ければ nil。
    private func preferredDailyPage(dateKey: String) throws -> Page? {
        let fetched = try fetchPages(kindRaw: PageKind.daily.rawValue)
        let matches = fetched.filter { page in
            page.dateKey == dateKey
        }
        return preferredPage(among: matches) { candidate in
            candidate.daily != nil
        }
    }

    /// その月の目次カード。複数あれば、中身があるものの中で一番古いもの。無ければ nil。
    private func preferredMonthlyPage(monthKey: String) throws -> Page? {
        let fetched = try fetchPages(kindRaw: PageKind.monthly.rawValue)
        let matches = fetched.filter { page in
            page.monthKey == monthKey
        }
        return preferredPage(among: matches) { candidate in
            candidate.monthly != nil
        }
    }

    /// 月の目次カードを、無ければ作って返す。中身が空なら足す。
    private func ensuredMonthlyPage(monthKey: String) throws -> Page {
        if let existing = try preferredMonthlyPage(monthKey: monthKey) {
            if existing.monthly == nil {
                _ = try attachMonthly(to: existing, monthKey: monthKey)
            }
            return existing
        }
        return try insertMonthly(monthKey: monthKey)
    }

    // MARK: - 作る

    /// 月の目次カードと中身を新しく作る。誰が作ったかは system（アプリ）。
    private func insertMonthly(monthKey: String) throws -> Page {
        let journal = try ensureJournal()
        let page = Page(
            kindRaw: PageKind.monthly.rawValue,
            dateKey: nil,
            monthKey: monthKey,
            createdByRaw: PageCreatedBy.system.rawValue
        )
        let monthly = MonthlyPage(monthKey: monthKey)
        context.insert(page)
        context.insert(monthly)
        page.monthly = monthly
        page.journal = journal
        try saveOrRollback()
        return page
    }

    /// 空の月の目次カードに、中身だけ足す。新しい Page は作らない。
    private func attachMonthly(to page: Page, monthKey: String) throws -> MonthlyPage {
        let monthly = MonthlyPage(monthKey: monthKey)
        context.insert(monthly)
        page.monthly = monthly
        try saveOrRollback()
        return monthly
    }

    /// 日の目次カード、中身、月へのつながりを新しく作る。
    private func insertDaily(
        dateKey: String,
        monthKey: String,
        createdBy: PageCreatedBy,
        monthlyIndex: Page
    ) throws -> DailyPage {
        let journal = try ensureJournal()
        let page = Page(
            kindRaw: PageKind.daily.rawValue,
            dateKey: dateKey,
            monthKey: monthKey,
            createdByRaw: createdBy.rawValue
        )
        let daily = DailyPage(dateKey: dateKey)
        let link = PageLink(
            fromPageID: page.id,
            toPageID: monthlyIndex.id,
            typeRaw: PageLinkType.dailyToMonthly.rawValue
        )
        context.insert(page)
        context.insert(daily)
        context.insert(link)
        page.daily = daily
        page.journal = journal
        try saveOrRollback()
        return daily
    }

    /// 空の日の目次カードに、中身だけ足す。新しい Page は作らない。
    ///
    /// 壊れた日ページを直しても、月への PageLink と Journal（手帳）は戻さない。
    /// 使う側は「つながりは必ずある」と仮定しない。
    private func attachDaily(to page: Page, dateKey: String) throws -> DailyPage {
        let daily = DailyPage(dateKey: dateKey)
        context.insert(daily)
        page.daily = daily
        try saveOrRollback()
        return daily
    }

    // MARK: - 古い方を選ぶ

    /// 作った時刻が一番古い手帳。同じ時刻なら id の文字順が小さい方。
    private func preferredJournal(among journals: [Journal]) -> Journal? {
        journals.min { lhs, rhs in
            isBefore(lhs.createdAt, lhs.id, rhs.createdAt, rhs.id)
        }
    }

    /// 使う目次カードを選ぶ。消さない。統合しない。
    ///
    /// 中身があるものを優先し、その中で作った時刻が一番古いもの。
    /// 中身があるものが無ければ、候補全体で一番古いもの。
    /// 時刻が同じなら、id の文字順（`uuidString`）が小さい方。この順序は変えない。
    private func preferredPage(among pages: [Page], hasContent: (Page) -> Bool) -> Page? {
        let withContent = pages.filter(hasContent)
        let candidates = withContent.isEmpty ? pages : withContent
        return candidates.min { lhs, rhs in
            isBefore(lhs.createdAt, lhs.id, rhs.createdAt, rhs.id)
        }
    }

    /// 保存する。失敗したときは変更を取り消してから、エラーを投げ直す。
    ///
    /// `rollback()` は context 全体に効く。呼び出し側の未保存の編集も消える。
    private func saveOrRollback() throws {
        do {
            try persist(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 古い方を先にする比較。id の文字は UUID の標準表記（`uuidString`。大文字の16進）で比べる。
    private func isBefore(_ lhsDate: Date, _ lhsID: UUID, _ rhsDate: Date, _ rhsID: UUID) -> Bool {
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhsID.uuidString < rhsID.uuidString
    }
}

/// ページを探す／作るとき、記録を書くとき、タスクを変えるとき、繰越するときのエラー。
///
/// 保存の失敗は、SwiftData が出したエラーをそのまま投げる。この enum には入れない。
enum JournalStoreError: Error, Equatable {
    /// 日付キー（`yyyy-MM-dd`）として読めない。
    case invalidDayKey(String)
    /// 月キー（`yyyy-MM`）として読めない。
    case invalidMonthKey(String)
    /// 気分が 1〜5 の外。
    case invalidMoodLevel(Int)
    /// 睡眠時間が 0.5〜24 の外、または 0.5 きざみでない。
    case invalidSleepHours(Double)
    /// その ID の習慣が無い。
    case habitNotFound(UUID)
    /// 習慣が属する月と、記録する日の月が違う。
    case habitMonthMismatch(habitID: UUID, dateKey: String)
    /// タスク名が、前後の空白と改行を除くと空。
    case emptyTitle
    /// その ID のタスクが無い。
    case taskNotFound(UUID)
    /// 繰越できない。日のタスクではない、完了、またはすでに繰越済み。
    case cannotCarryForward(UUID)
    /// 繰越済みではないので、取り消しできない。
    case notCarriedForward(UUID)
}

// MARK: - 日ごとの記録

extension JournalStore {
    /// その日の1行。無ければ nil。
    ///
    /// 同じ日が複数あるときは、更新時刻が一番新しいもの。同時刻なら id の文字順が大きい方。
    /// 書くときも、この関数でどれを使うか決める。
    func logLine(dateKey: String) throws -> MonthlyLogLine? {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        let stored = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        let sameDay = stored.filter { line in
            line.dateKey == dateKey
        }
        return latest(
            in: sameDay,
            updatedAt: { line in line.updatedAt },
            identifier: { line in line.id }
        )
    }

    /// その日の気分。無ければ nil。選び方は `logLine` と同じ。
    func mood(dateKey: String) throws -> MoodEntry? {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        let stored = try context.fetch(FetchDescriptor<MoodEntry>())
        let sameDay = stored.filter { entry in
            entry.dateKey == dateKey
        }
        return latest(
            in: sameDay,
            updatedAt: { entry in entry.updatedAt },
            identifier: { entry in entry.id }
        )
    }

    /// その日の睡眠。無ければ nil。選び方は `logLine` と同じ。
    ///
    /// 日付は「起きた日」の想定（夜に寝て翌朝起きたなら、朝の日付）。
    func sleep(dateKey: String) throws -> SleepEntry? {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        let stored = try context.fetch(FetchDescriptor<SleepEntry>())
        let sameDay = stored.filter { entry in
            entry.dateKey == dateKey
        }
        return latest(
            in: sameDay,
            updatedAt: { entry in entry.updatedAt },
            identifier: { entry in entry.id }
        )
    }

    /// 月ページの、その日の1行を書く。
    ///
    /// 前後の空白と改行を除いて空なら、その日の行を全部消す。無ければ何も作らない。
    /// 空でなければ、入力の文字はそのまま保存する（前後の空白は削らない）。
    /// 今の文字と同じなら、何もしない（保存も、更新時刻も変えない）。
    /// 同じ日が複数あるときは、`logLine` と同じ1件だけを書き換える。
    func setLogLine(dateKey: String, text: String) throws {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try deleteLogLines(on: dateKey)
            return
        }
        if let chosen = try logLine(dateKey: dateKey) {
            if chosen.text == text {
                return
            }
            guard let monthOfDay = DateKey.monthKey(ofDayKey: dateKey) else {
                throw JournalStoreError.invalidDayKey(dateKey)
            }
            _ = try findOrCreateMonthly(monthKey: monthOfDay)
            chosen.text = text
            chosen.updatedAt = currentDate()
            try saveOrRollback()
            return
        }
        guard let monthOfDay = DateKey.monthKey(ofDayKey: dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        let monthly = try findOrCreateMonthly(monthKey: monthOfDay)
        let line = MonthlyLogLine(
            dateKey: dateKey,
            text: text,
            updatedAt: currentDate()
        )
        context.insert(line)
        line.monthly = monthly
        try saveOrRollback()
    }

    /// その日の気分を書く。1〜5。nil なら、その日の分を全部消す。
    ///
    /// Daily（その日のページ）は作らない。今と同じ値なら、何もしない。
    /// 同じ日が複数あるときは、`mood` と同じ1件だけを書き換える。
    func setMood(dateKey: String, level: Int?) throws {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        if let moodLevel = level {
            if moodLevel < 1 || moodLevel > 5 {
                throw JournalStoreError.invalidMoodLevel(moodLevel)
            }
        }
        guard let moodLevel = level else {
            try deleteMoods(on: dateKey)
            return
        }
        if let chosen = try mood(dateKey: dateKey) {
            if chosen.level == moodLevel {
                return
            }
            chosen.level = moodLevel
            chosen.updatedAt = currentDate()
            try saveOrRollback()
            return
        }
        let entry = MoodEntry(
            dateKey: dateKey,
            level: moodLevel,
            updatedAt: currentDate()
        )
        context.insert(entry)
        try saveOrRollback()
    }

    /// 睡眠時間を書く。nil なら、その日の分を全部消す。
    ///
    /// 日付は「起きた日」の想定（夜に寝て翌朝起きたなら、朝の日付）。
    /// 0.5〜24 時間で、0.5 きざみだけ。Daily（その日のページ）は作らない。
    /// 今と同じ値なら、何もしない。同じ日が複数あるときは、`sleep` と同じ1件だけを書き換える。
    func setSleep(dateKey: String, hours: Double?) throws {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        if let sleepHours = hours {
            if isValidSleepHours(sleepHours) == false {
                throw JournalStoreError.invalidSleepHours(sleepHours)
            }
        }
        guard let sleepHours = hours else {
            try deleteSleeps(on: dateKey)
            return
        }
        if let chosen = try sleep(dateKey: dateKey) {
            if chosen.hours == sleepHours {
                return
            }
            chosen.hours = sleepHours
            chosen.updatedAt = currentDate()
            try saveOrRollback()
            return
        }
        let entry = SleepEntry(
            dateKey: dateKey,
            hours: sleepHours,
            updatedAt: currentDate()
        )
        context.insert(entry)
        try saveOrRollback()
    }

    /// 習慣のチェックを付ける、または外す。付けたら true、外したら false。
    ///
    /// 同じ習慣・同じ日が複数あるときは、全部消して false を返す。
    /// 習慣に月が付いていて、その月と日付の月が違うときはエラー。月が無い習慣は、どの日でもよい。
    /// Daily（その日のページ）は作らない。
    func toggleHabit(habitID: UUID, dateKey: String) throws -> Bool {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        let habits = try context.fetch(FetchDescriptor<Habit>())
        guard let habit = habits.first(where: { candidate in
            candidate.id == habitID
        }) else {
            throw JournalStoreError.habitNotFound(habitID)
        }
        if let habitMonth = habit.monthly?.monthKey {
            guard let monthOfDay = DateKey.monthKey(ofDayKey: dateKey) else {
                throw JournalStoreError.invalidDayKey(dateKey)
            }
            if habitMonth != monthOfDay {
                throw JournalStoreError.habitMonthMismatch(habitID: habitID, dateKey: dateKey)
            }
        }
        let stored = try context.fetch(FetchDescriptor<HabitEntry>())
        let matches = stored.filter { entry in
            entry.habitID == habitID && entry.dateKey == dateKey
        }
        if matches.isEmpty {
            let entry = HabitEntry(
                habitID: habitID,
                dateKey: dateKey,
                isDone: true,
                updatedAt: currentDate()
            )
            context.insert(entry)
            try saveOrRollback()
            return true
        }
        for entry in matches {
            context.delete(entry)
        }
        try saveOrRollback()
        return false
    }
}

// MARK: - タスク

extension JournalStore {
    /// その日のタスクを1件足す。進み具合は未完（open）。並びは、その日の最大 + 1。無ければ 0。
    ///
    /// タイトルは前後の空白と改行を削る。削ったあと空なら、何も作らない。
    /// 履歴を1件足す（作った、あとの進み具合は open）。
    func addDailyTask(
        dateKey: String,
        title: String,
        createdBy: PageCreatedBy = .user
    ) throws -> JournalTask {
        guard DateKey.isValidDayKey(dateKey) else {
            throw JournalStoreError.invalidDayKey(dateKey)
        }
        let trimmedTitle = normalizedTitle(title)
        if trimmedTitle.isEmpty {
            throw JournalStoreError.emptyTitle
        }
        let daily = try findOrCreateDaily(dateKey: dateKey, createdBy: createdBy)
        let existing = try tasks(onDaily: daily)
        let order = nextSortOrder(among: existing)
        let instant = currentDate()
        let task = JournalTask(
            title: trimmedTitle,
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: nil,
            carriedToTaskID: nil,
            sortOrder: order,
            createdAt: instant,
            completedAt: nil
        )
        context.insert(task)
        task.daily = daily
        appendHistory(
            taskID: task.id,
            action: .created,
            fromProgress: nil,
            toProgress: .open,
            at: instant
        )
        try saveOrRollback()
        return task
    }

    /// その月のタスクを1件足す。範囲は monthly。並びは、その月の最大 + 1。無ければ 0。
    ///
    /// タイトルは前後の空白と改行を削る。削ったあと空なら、何も作らない。
    func addMonthlyTask(monthKey: String, title: String) throws -> JournalTask {
        guard DateKey.isValidMonthKey(monthKey) else {
            throw JournalStoreError.invalidMonthKey(monthKey)
        }
        let trimmedTitle = normalizedTitle(title)
        if trimmedTitle.isEmpty {
            throw JournalStoreError.emptyTitle
        }
        let monthly = try findOrCreateMonthly(monthKey: monthKey)
        let existing = try tasks(onMonthly: monthly)
        let order = nextSortOrder(among: existing)
        let instant = currentDate()
        let task = JournalTask(
            title: trimmedTitle,
            scopeRaw: TaskScope.monthly.rawValue,
            progressRaw: TaskProgress.open.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: nil,
            carriedToTaskID: nil,
            sortOrder: order,
            createdAt: instant,
            completedAt: nil
        )
        context.insert(task)
        task.monthly = monthly
        appendHistory(
            taskID: task.id,
            action: .created,
            fromProgress: nil,
            toProgress: .open,
            at: instant
        )
        try saveOrRollback()
        return task
    }

    /// タスク名を変える。同じ名前なら、履歴も増やさない。
    func editTaskTitle(taskID: UUID, title: String) throws {
        guard let found = try storedTask(matchingID: taskID) else {
            throw JournalStoreError.taskNotFound(taskID)
        }
        let trimmedTitle = normalizedTitle(title)
        if trimmedTitle.isEmpty {
            throw JournalStoreError.emptyTitle
        }
        if found.title == trimmedTitle {
            return
        }
        found.title = trimmedTitle
        appendHistory(
            taskID: found.id,
            action: .edited,
            fromProgress: nil,
            toProgress: nil,
            at: currentDate()
        )
        try saveOrRollback()
    }

    /// タスクを消す。履歴は残す。繰越の相手がいれば、相手側の ID だけを空にする。
    ///
    /// 相手の「繰越済み」は変えない。相手の履歴は増やさない。
    /// 相手の ID を空にするのは、その ID が今消すタスクを指しているときだけ。
    /// 履歴の追加、相手の ID、削除は、最後の1回の保存でまとめる。
    func deleteTask(taskID: UUID) throws {
        guard let found = try storedTask(matchingID: taskID) else {
            throw JournalStoreError.taskNotFound(taskID)
        }
        let removedID = found.id
        let fromProgress = found.progress
        let sourceID = found.carriedFromTaskID
        let destinationID = found.carriedToTaskID
        // 先に探す。ここまでが、失敗しうる処理。
        let source = try sourceID.flatMap { try storedTask(matchingID: $0) }
        let destination = try destinationID.flatMap { try storedTask(matchingID: $0) }
        // ここから先は、保存の直前まで失敗しない。
        let instant = currentDate()
        appendHistory(
            taskID: removedID,
            action: .deleted,
            fromProgress: fromProgress,
            toProgress: nil,
            at: instant
        )
        if let source, source.id != removedID, source.carriedToTaskID == removedID {
            source.carriedToTaskID = nil
        }
        if let destination, destination.id != removedID, destination.carriedFromTaskID == removedID {
            destination.carriedFromTaskID = nil
        }
        context.delete(found)
        try saveOrRollback()
    }

    /// 記号タップ1回ぶん、進み具合を進める。繰越済みなら、今のまま返して履歴は増やさない。
    ///
    /// 進み具合（`progress`）は、画面から直接書かない。必ずこの関数を使う。
    /// 完了になったら完了時刻を入れる。完了から外れたら、完了時刻を空にする。
    func cycleProgress(taskID: UUID) throws -> TaskProgress {
        guard let found = try storedTask(matchingID: taskID) else {
            throw JournalStoreError.taskNotFound(taskID)
        }
        let before = found.progress
        if TaskRules.isTappable(progress: before, isCarriedForward: found.isCarriedForward) == false {
            return before
        }
        let after = TaskRules.progressAfterTap(
            progress: before,
            isCarriedForward: found.isCarriedForward
        )
        found.progress = after
        let instant = currentDate()
        if after == .done {
            found.completedAt = instant
        } else {
            found.completedAt = nil
        }
        appendHistory(
            taskID: found.id,
            action: .progressChanged,
            fromProgress: before,
            toProgress: after,
            at: instant
        )
        try saveOrRollback()
        return after
    }
}

// MARK: - 繰越

extension JournalStore {
    /// 翌日の Daily（その日のページ）へコピーを作り、そのコピーを返す。
    ///
    /// 繰越できるのは、日のタスクで、未完（open）か一部（partial）で、まだ繰越していないときだけ。
    /// 月のタスク、結び付く日が無い、完了、すでに繰越済み、のときは `cannotCarryForward`。何も変えない。
    /// 元の日付から翌日が計算できないとき、日ページに目次カード（Page）が無いときも、同じエラー。何も作らない。
    /// 翌日のページが無ければ作る。誰が作ったかは carryOver（繰越で作った）。あれば、そのまま使い、末尾に足す。
    /// 元の進み具合は変えない。元は繰越済みにし、コピーの ID を入れる。
    /// ページのつながり（PageLink）は、元の日の目次カードから翌日の日の目次カードへ。種類は carryOver。
    /// 日ページ自体の ID ではない。日→月のつながりと同じ。同じ組み合わせがあれば足さない。
    /// 翌日のページを用意する保存だけは、先に `findOrCreateDaily` の中で行われる。
    /// コピー、元の更新、つながり、履歴は、最後の1回で保存する。
    func carryForward(taskID: UUID) throws -> JournalTask {
        guard let source = try storedTask(matchingID: taskID) else {
            throw JournalStoreError.taskNotFound(taskID)
        }
        // 繰越できないときは、ここで戻る。翌日のページは作らない。
        guard let sourceDaily = source.daily, source.scope == .daily else {
            throw JournalStoreError.cannotCarryForward(taskID)
        }
        if TaskRules.canCarryForward(
            progress: source.progress,
            isCarriedForward: source.isCarriedForward
        ) == false {
            throw JournalStoreError.cannotCarryForward(taskID)
        }
        let sourceDayKey = sourceDaily.dateKey
        guard let followingDayKey = DateKey.nextDayKey(after: sourceDayKey) else {
            throw JournalStoreError.cannotCarryForward(taskID)
        }
        guard let originPageID = sourceDaily.page?.id else {
            throw JournalStoreError.cannotCarryForward(taskID)
        }
        let sourceID = source.id
        let sourceTitle = source.title
        let sourceProgress = source.progress

        let destinationDaily = try findOrCreateDaily(
            dateKey: followingDayKey,
            createdBy: .carryOver
        )
        guard let destinationPageID = destinationDaily.page?.id else {
            throw JournalStoreError.cannotCarryForward(taskID)
        }
        let existingTasks = try tasks(onDaily: destinationDaily)
        let order = nextSortOrder(among: existingTasks)
        let linkAlreadyExists = try containsCarryOverLink(
            from: originPageID,
            to: destinationPageID
        )

        // ここから先は、保存の直前まで失敗しない。
        let instant = currentDate()
        let copy = JournalTask(
            title: sourceTitle,
            scopeRaw: TaskScope.daily.rawValue,
            progressRaw: sourceProgress.rawValue,
            isCarriedForward: false,
            carriedFromTaskID: sourceID,
            carriedToTaskID: nil,
            sortOrder: order,
            createdAt: instant,
            completedAt: nil
        )
        context.insert(copy)
        copy.daily = destinationDaily
        source.isCarriedForward = true
        source.carriedToTaskID = copy.id
        if linkAlreadyExists == false {
            let link = PageLink(
                fromPageID: originPageID,
                toPageID: destinationPageID,
                typeRaw: PageLinkType.carryOver.rawValue
            )
            context.insert(link)
        }
        appendHistory(
            taskID: sourceID,
            action: .carriedForward,
            fromProgress: sourceProgress,
            toProgress: sourceProgress,
            relatedTaskID: copy.id,
            relatedDateKey: followingDayKey,
            at: instant
        )
        appendHistory(
            taskID: copy.id,
            action: .created,
            fromProgress: nil,
            toProgress: sourceProgress,
            relatedTaskID: sourceID,
            relatedDateKey: sourceDayKey,
            at: instant
        )
        try saveOrRollback()
        return copy
    }

    /// 繰越を取り消す。元は繰越前の □ か ◧ に戻る。進み具合は変えない。
    ///
    /// 繰越済みでないときは `notCarriedForward`。タスクが無いときは `taskNotFound`。
    /// コピーの履歴が「作った」1件だけなら、コピーを消す。「消した」履歴を1件足す。
    /// コピーが変更済みなら、コピーは残し、`carriedFromTaskID` だけ空にする。
    /// コピーが見つからないときは、コピーには触らない。
    /// コピーの ID が元タスク自身のときは、消さない。
    /// ページのつながり（PageLink）は消さない。変更は最後の1回で保存する。
    func cancelCarryForward(taskID: UUID) throws {
        guard let source = try storedTask(matchingID: taskID) else {
            throw JournalStoreError.taskNotFound(taskID)
        }
        if source.isCarriedForward == false {
            throw JournalStoreError.notCarriedForward(taskID)
        }
        // 先に、コピーと履歴を探す。このあいだは、まだ何も変えない。
        let sourceID = source.id
        let sourceProgress = source.progress
        let carriedToID = source.carriedToTaskID
        let foundCopy = try carriedToID.flatMap { candidateID in
            try storedTask(matchingID: candidateID)
        }
        let linkedCopy: JournalTask?
        if let foundCopy, foundCopy.id != sourceID {
            linkedCopy = foundCopy
        } else {
            linkedCopy = nil
        }
        let relatedID = linkedCopy?.id ?? carriedToID
        let relatedDayKey: String?
        let copyProgress: TaskProgress?
        let copyIsUnmodified: Bool
        if let linkedCopy {
            relatedDayKey = linkedCopy.daily?.dateKey
            copyProgress = linkedCopy.progress
            let copyHistories = try storedHistories(matchingTaskID: linkedCopy.id)
            copyIsUnmodified = isUnmodifiedCarryCopy(copyHistories)
        } else {
            relatedDayKey = nil
            copyProgress = nil
            copyIsUnmodified = false
        }

        // ここから先は、保存の直前まで失敗しない。
        let instant = currentDate()
        if let linkedCopy {
            if copyIsUnmodified {
                appendHistory(
                    taskID: linkedCopy.id,
                    action: .deleted,
                    fromProgress: copyProgress,
                    toProgress: nil,
                    at: instant
                )
                context.delete(linkedCopy)
            } else {
                linkedCopy.carriedFromTaskID = nil
            }
        }
        source.isCarriedForward = false
        source.carriedToTaskID = nil
        appendHistory(
            taskID: sourceID,
            action: .carryCancelled,
            fromProgress: sourceProgress,
            toProgress: sourceProgress,
            relatedTaskID: relatedID,
            relatedDateKey: relatedDayKey,
            at: instant
        )
        try saveOrRollback()
    }
}

// MARK: - 記録とタスクの内部

extension JournalStore {
    // 検索に `#Predicate`（検索条件）は使わない。モデルを全部取り、Swift で日付などを比べる。
    // Optional の項目を `#Predicate` に入れる書き方は、ここでは使わない。

    /// 更新時刻が一番新しいもの。同時刻なら id の文字順が大きい方。空なら nil。
    private func latest<Record>(
        in records: [Record],
        updatedAt updatedAtOf: (Record) -> Date,
        identifier identifierOf: (Record) -> UUID
    ) -> Record? {
        records.max { lhs, rhs in
            isBefore(
                updatedAtOf(lhs),
                identifierOf(lhs),
                updatedAtOf(rhs),
                identifierOf(rhs)
            )
        }
    }

    /// その日の1行を全部消す。無ければ何もしない。
    private func deleteLogLines(on dateKey: String) throws {
        let stored = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        let sameDay = stored.filter { line in
            line.dateKey == dateKey
        }
        try deleteAll(sameDay)
    }

    /// その日の気分を全部消す。無ければ何もしない。
    private func deleteMoods(on dateKey: String) throws {
        let stored = try context.fetch(FetchDescriptor<MoodEntry>())
        let sameDay = stored.filter { entry in
            entry.dateKey == dateKey
        }
        try deleteAll(sameDay)
    }

    /// その日の睡眠を全部消す。無ければ何もしない。
    private func deleteSleeps(on dateKey: String) throws {
        let stored = try context.fetch(FetchDescriptor<SleepEntry>())
        let sameDay = stored.filter { entry in
            entry.dateKey == dateKey
        }
        try deleteAll(sameDay)
    }

    /// 渡された記録を全部消して、1回だけ保存する。空なら保存しない。
    private func deleteAll<Record: PersistentModel>(_ records: [Record]) throws {
        if records.isEmpty {
            return
        }
        for record in records {
            context.delete(record)
        }
        try saveOrRollback()
    }

    /// 0.5 以上 24 以下で、0.5 きざみのときだけ true。
    ///
    /// 0.5 は 2 の累乗なので、正しい 0.5 きざみは 2 倍すると整数になる。
    private func isValidSleepHours(_ hours: Double) -> Bool {
        if hours.isNaN || hours.isInfinite {
            return false
        }
        if hours < 0.5 || hours > 24 {
            return false
        }
        let doubled = hours * 2
        if doubled.isNaN || doubled.isInfinite {
            return false
        }
        return doubled == doubled.rounded()
    }

    /// 前後の空白と改行を削ったタスク名。
    private func normalizedTitle(_ rawTitle: String) -> String {
        rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// id が一致するタスク。複数なら、作った時刻が一番古いもの。同時刻なら id の文字順が小さい方。
    private func storedTask(matchingID taskID: UUID) throws -> JournalTask? {
        let stored = try context.fetch(FetchDescriptor<JournalTask>())
        let matches = stored.filter { candidate in
            candidate.id == taskID
        }
        return matches.min { lhs, rhs in
            isBefore(lhs.createdAt, lhs.id, rhs.createdAt, rhs.id)
        }
    }

    /// その日のページに付いているタスク。保存済みと、ページ側の一覧の両方を見る。
    ///
    /// 並びは sortOrder、同じなら作った時刻、それも同じなら id の文字順。順番は毎回同じ。
    func tasks(onDaily page: DailyPage) throws -> [JournalTask] {
        var gathered: [UUID: JournalTask] = [:]
        let stored = try context.fetch(FetchDescriptor<JournalTask>())
        for candidate in stored {
            if candidate.daily?.id == page.id {
                gathered[candidate.id] = candidate
            }
        }
        let listed = page.tasks ?? []
        for candidate in listed {
            gathered[candidate.id] = candidate
        }
        return sortedTasks(Array(gathered.values))
    }

    /// その月のページに付いているタスク。保存済みと、ページ側の一覧の両方を見る。
    ///
    /// 並びは sortOrder、同じなら作った時刻、それも同じなら id の文字順。順番は毎回同じ。
    func tasks(onMonthly page: MonthlyPage) throws -> [JournalTask] {
        var gathered: [UUID: JournalTask] = [:]
        let stored = try context.fetch(FetchDescriptor<JournalTask>())
        for candidate in stored {
            if candidate.monthly?.id == page.id {
                gathered[candidate.id] = candidate
            }
        }
        let listed = page.tasks ?? []
        for candidate in listed {
            gathered[candidate.id] = candidate
        }
        return sortedTasks(Array(gathered.values))
    }

    /// sortOrder、作った時刻、id の文字順。小さい方を先にする。
    private func sortedTasks(_ items: [JournalTask]) -> [JournalTask] {
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

    /// 並び順。タスクが無ければ 0。あれば最大 + 1。
    ///
    /// 最大が Int の上限のときは、その値のままにする。足すと落ちるため。
    private func nextSortOrder(among items: [JournalTask]) -> Int {
        guard let highest = items.map({ candidate in candidate.sortOrder }).max() else {
            return 0
        }
        if highest == Int.max {
            return highest
        }
        return highest + 1
    }

    /// 履歴を1件足す。書き換えはしない。
    ///
    /// 繰越の相手と日付は、渡したときだけ入る。省略したときは空。
    private func appendHistory(
        taskID: UUID,
        action: TaskHistoryAction,
        fromProgress: TaskProgress?,
        toProgress: TaskProgress?,
        relatedTaskID: UUID? = nil,
        relatedDateKey: String? = nil,
        at instant: Date
    ) {
        let history = TaskHistory(
            taskID: taskID,
            actionRaw: action.rawValue,
            fromProgressRaw: fromProgress?.rawValue,
            toProgressRaw: toProgress?.rawValue,
            relatedTaskID: relatedTaskID,
            relatedDateKey: relatedDateKey,
            at: instant
        )
        context.insert(history)
    }

    /// そのタスクの履歴。検索条件（`#Predicate`）は使わず、全部取ってから ID で絞る。
    private func storedHistories(matchingTaskID taskID: UUID) throws -> [TaskHistory] {
        let stored = try context.fetch(FetchDescriptor<TaskHistory>())
        return stored.filter { item in
            item.taskID == taskID
        }
    }

    /// 繰越のつながりが、同じ元・同じ先・種類 carryOver で既にあるか。
    ///
    /// 目次カード（Page）の ID で比べる。種類が違うつながりは、別のものとして数える。
    private func containsCarryOverLink(from originPageID: UUID, to destinationPageID: UUID) throws -> Bool {
        let stored = try context.fetch(FetchDescriptor<PageLink>())
        return stored.contains { link in
            link.fromPageID == originPageID
                && link.toPageID == destinationPageID
                && link.typeRaw == PageLinkType.carryOver.rawValue
        }
    }

    /// コピーが未変更か。履歴が「作った」1件だけのときだけ true。
    private func isUnmodifiedCarryCopy(_ items: [TaskHistory]) -> Bool {
        guard items.count == 1 else {
            return false
        }
        guard let only = items.first else {
            return false
        }
        return only.actionRaw == TaskHistoryAction.created.rawValue
    }
}
