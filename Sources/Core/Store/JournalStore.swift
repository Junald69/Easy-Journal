import Foundation
import SwiftData

/// ページを探す／作る保存係。
///
/// 画面から直接 insert（保存場所へ追加）せず、ここを通す。
/// 同じ端末の通常の使い方では、1日1枚、1か月1枚をここで守る。同じ日付がすでにあれば、新しくは作らない。
/// 同期や別の処理で重複ができたときは、中身があるものを優先し、その中で一番古いものを使う。削除はしない。
/// ModelContext（読み書きの窓口）を作ったスレッドから使う前提。
/// 保存に失敗したときは、未保存の変更を取り消してから、そのエラーをそのまま投げる。握りつぶさない。`fatalError` にもしない。
final class JournalStore {
    /// 記録の読み書きに使う場所。
    private let context: ModelContext

    /// 保存の入れ物から作った context（読み書きの窓口）を渡す。
    init(context: ModelContext) {
        self.context = context
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
            try context.save()
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

/// ページを探す／作るときのエラー。キーが不正なときだけ。
///
/// 保存の失敗は、SwiftData が出したエラーをそのまま投げる。この enum には入れない。
enum JournalStoreError: Error, Equatable {
    /// 日付キー（`yyyy-MM-dd`）として読めない。
    case invalidDayKey(String)
    /// 月キー（`yyyy-MM`）として読めない。
    case invalidMonthKey(String)
}
