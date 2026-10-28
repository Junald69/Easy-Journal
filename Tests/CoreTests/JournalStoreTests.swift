import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// ページを探す／作る。メモリ上の保存だけ。App Group は使わない。
final class JournalStoreTests: XCTestCase {
    /// 同じ dateKey で2回呼んでも、日の中身・日の目次カード・PageLink は1つずつ。
    func testFindOrCreateDailyTwiceKeepsSingleDailyPageAndLink() throws {
        let (store, context, _) = try makeStore()
        let first = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .user)
        let second = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .user)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)
        XCTAssertEqual(try countPages(kindRaw: PageKind.daily.rawValue, in: context), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 1)
    }

    /// 日を作ると、その月の月ページと、日→月の PageLink ができる。
    func testCreatingDailyAlsoCreatesMonthlyAndLink() throws {
        let (store, context, _) = try makeStore()
        let daily = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .user)

        let monthlies = try context.fetch(FetchDescriptor<MonthlyPage>())
        XCTAssertEqual(monthlies.count, 1)
        XCTAssertEqual(monthlies.first?.monthKey, "2026-10")
        XCTAssertEqual(monthlies.first?.page?.kindRaw, "monthly")
        XCTAssertEqual(monthlies.first?.page?.kind, .monthly)
        XCTAssertEqual(monthlies.first?.page?.monthKey, "2026-10")
        XCTAssertEqual(monthlies.first?.page?.createdByRaw, "system")
        XCTAssertEqual(monthlies.first?.page?.createdBy, .system)
        XCTAssertNil(monthlies.first?.page?.dateKey)

        let pages = try context.fetch(FetchDescriptor<Page>())
        let dailyIndex = pages.first { page in
            page.kindRaw == PageKind.daily.rawValue
        }
        XCTAssertEqual(dailyIndex?.dateKey, "2026-10-27")
        XCTAssertEqual(dailyIndex?.monthKey, "2026-10")
        XCTAssertEqual(daily.dateKey, "2026-10-27")
        XCTAssertEqual(dailyIndex?.daily?.id, daily.id)
        XCTAssertEqual(daily.page?.id, dailyIndex?.id)

        let links = try context.fetch(FetchDescriptor<PageLink>())
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.typeRaw, "dailyToMonthly")
        XCTAssertEqual(links.first?.type, .dailyToMonthly)
        XCTAssertEqual(links.first?.fromPageID, dailyIndex?.id)
        XCTAssertEqual(links.first?.toPageID, monthlies.first?.page?.id)
        XCTAssertNotEqual(links.first?.fromPageID, daily.id)
        XCTAssertNotEqual(links.first?.toPageID, monthlies.first?.id)

        let journals = try context.fetch(FetchDescriptor<Journal>())
        XCTAssertEqual(journals.count, 1)
        XCTAssertEqual(dailyIndex?.journal?.id, journals.first?.id)
        XCTAssertEqual(monthlies.first?.page?.journal?.id, journals.first?.id)
    }

    /// 月が先にあるとき、日を作っても月は増えない。
    func testExistingMonthlyIsReusedWhenCreatingDaily() throws {
        let (store, context, _) = try makeStore()
        let monthly = try store.findOrCreateMonthly(monthKey: "2026-10")
        let sameMonthly = try store.findOrCreateMonthly(monthKey: "2026-10")
        XCTAssertEqual(monthly.id, sameMonthly.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 1)

        let daily = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .user)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-10")?.id, monthly.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 2)
        XCTAssertEqual(try countPages(kindRaw: PageKind.monthly.rawValue, in: context), 1)
        XCTAssertEqual(try countPages(kindRaw: PageKind.daily.rawValue, in: context), 1)
        XCTAssertEqual(daily.page?.monthKey, "2026-10")

        let links = try context.fetch(FetchDescriptor<PageLink>())
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.toPageID, monthly.page?.id)
        XCTAssertEqual(links.first?.fromPageID, daily.page?.id)
    }

    /// 別の月の日を作ると、別の月ページができる。12月と1月（年をまたぐ）。
    func testDailyAcrossYearBoundaryCreatesTwoMonthlies() throws {
        let (store, context, _) = try makeStore()
        let decemberDaily = try store.findOrCreateDaily(dateKey: "2026-12-31", createdBy: .user)
        let januaryDaily = try store.findOrCreateDaily(dateKey: "2027-01-01", createdBy: .user)

        XCTAssertEqual(decemberDaily.page?.monthKey, "2026-12")
        XCTAssertEqual(januaryDaily.page?.monthKey, "2027-01")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 1)

        let december = try store.findMonthly(monthKey: "2026-12")
        let january = try store.findMonthly(monthKey: "2027-01")
        XCTAssertEqual(december?.monthKey, "2026-12")
        XCTAssertEqual(january?.monthKey, "2027-01")
        XCTAssertNotEqual(december?.id, january?.id)
        XCTAssertEqual(december?.page?.kindRaw, "monthly")
        XCTAssertEqual(january?.page?.kindRaw, "monthly")

        guard let decemberFromID = decemberDaily.page?.id,
              let decemberToID = december?.page?.id,
              let januaryFromID = januaryDaily.page?.id,
              let januaryToID = january?.page?.id else {
            XCTFail("日ページまたは月ページの id が取れませんでした")
            return
        }
        let links = try context.fetch(FetchDescriptor<PageLink>())
        XCTAssertTrue(links.contains { link in
            link.fromPageID == decemberFromID
                && link.toPageID == decemberToID
                && link.typeRaw == "dailyToMonthly"
        })
        XCTAssertTrue(links.contains { link in
            link.fromPageID == januaryFromID
                && link.toPageID == januaryToID
                && link.typeRaw == "dailyToMonthly"
        })
    }

    /// findDaily / findMonthly は、無ければ nil、あれば返す。何も作らない。
    func testFindReturnsExistingAndNilWithoutCreating() throws {
        let (store, context, _) = try makeStore()
        XCTAssertNil(try store.findDaily(dateKey: "2026-10-27"))
        XCTAssertNil(try store.findMonthly(monthKey: "2026-10"))
        try assertNothingStored(in: context)

        let daily = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .user)
        let pageCount = try context.fetchCount(FetchDescriptor<Page>())
        let dailyCount = try context.fetchCount(FetchDescriptor<DailyPage>())
        let monthlyCount = try context.fetchCount(FetchDescriptor<MonthlyPage>())
        let linkCount = try context.fetchCount(FetchDescriptor<PageLink>())
        let journalCount = try context.fetchCount(FetchDescriptor<Journal>())

        XCTAssertEqual(try store.findDaily(dateKey: "2026-10-27")?.id, daily.id)
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-10")?.monthKey, "2026-10")
        XCTAssertNil(try store.findDaily(dateKey: "2026-10-28"))
        XCTAssertNil(try store.findMonthly(monthKey: "2026-11"))

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), pageCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), dailyCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), monthlyCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), linkCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), journalCount)
    }

    /// 不正なキーはエラーになり、何も作られない。
    func testInvalidKeysThrowAndCreateNothing() throws {
        let (store, context, _) = try makeStore()
        let invalidDayKeys = ["2026-02-30", "2026-1-5", ""]
        for invalidDay in invalidDayKeys {
            XCTAssertThrowsError(
                try store.findOrCreateDaily(dateKey: invalidDay, createdBy: .user)
            ) { error in
                XCTAssertEqual(error as? JournalStoreError, .invalidDayKey(invalidDay))
            }
        }

        let invalidMonthKeys = ["", "2026-1", "2026-13", "2026-10-27"]
        for invalidMonth in invalidMonthKeys {
            XCTAssertThrowsError(
                try store.findOrCreateMonthly(monthKey: invalidMonth)
            ) { error in
                XCTAssertEqual(error as? JournalStoreError, .invalidMonthKey(invalidMonth))
            }
        }

        try assertNothingStored(in: context)
    }

    /// createdBy が保存される。すでにある日を、別の createdBy で呼んでも変わらない。
    func testCreatedByIsStoredAndNotReplaced() throws {
        let (store, context, _) = try makeStore()
        let daily = try store.findOrCreateDaily(dateKey: "2026-05-02", createdBy: .carryOver)
        XCTAssertEqual(daily.page?.createdBy, .carryOver)
        XCTAssertEqual(daily.page?.createdByRaw, "carryOver")

        let monthly = try store.findMonthly(monthKey: "2026-05")
        XCTAssertEqual(monthly?.page?.createdBy, .system)
        XCTAssertEqual(monthly?.page?.createdByRaw, "system")

        let again = try store.findOrCreateDaily(dateKey: "2026-05-02", createdBy: .user)
        XCTAssertEqual(again.id, daily.id)
        XCTAssertEqual(again.page?.createdBy, .carryOver)
        XCTAssertEqual(again.page?.createdByRaw, "carryOver")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)
        XCTAssertEqual(try countPages(kindRaw: PageKind.daily.rawValue, in: context), 1)
    }

    /// 1回目で手帳が1冊でき、2回目も1冊のまま。2冊入れておくと古い方を返し、数は増えない。
    func testEnsureJournalCreatesOneAndReturnsOldest() throws {
        let (store, context, _) = try makeStore()
        let first = try store.ensureJournal()
        let second = try store.ensureJournal()
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.title, "My Journal")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 1)

        let (anotherStore, anotherContext, _) = try makeStore()
        guard let newerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
              let olderID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") else {
            XCTFail("UUID の文字列を読めませんでした")
            return
        }
        // 新しい方を先に作る。古い方は id の文字順が大きい。時刻で古い方が選ばれる。
        let newer = Journal(
            id: newerID,
            title: "新しい手帳",
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let older = Journal(
            id: olderID,
            title: "古い手帳",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        anotherContext.insert(newer)
        anotherContext.insert(older)
        try anotherContext.save()

        let found = try anotherStore.ensureJournal()
        XCTAssertEqual(found.id, older.id)
        XCTAssertEqual(found.title, "古い手帳")
        XCTAssertEqual(try anotherContext.fetchCount(FetchDescriptor<Journal>()), 2)
    }

    /// 作った時刻が同じ手帳が2冊あるときは、id の文字順が小さい方を返す。
    func testEnsureJournalSameTimeReturnsSmallerID() throws {
        guard let smallerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
              let largerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") else {
            XCTFail("UUID の文字列を読めませんでした")
            return
        }
        XCTAssertLessThan(smallerID.uuidString, largerID.uuidString)

        let (store, context, _) = try makeStore()
        let sameTime = Date(timeIntervalSince1970: 1_700_000_000)
        // 文字順が大きい方を先に入れる。同時刻なら、小さい id が選ばれる。
        let larger = Journal(id: largerID, title: "大きい", createdAt: sameTime)
        let smaller = Journal(id: smallerID, title: "小さい", createdAt: sameTime)
        context.insert(larger)
        context.insert(smaller)
        try context.save()

        let found = try store.ensureJournal()
        XCTAssertEqual(found.id, smallerID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 2)
    }

    /// 同じ日の組を2つ入れておくと、古い方を返す。3組目は作らない。ほかも増えない。
    func testDuplicateDailyReturnsOldestAndDoesNotCreateThird() throws {
        guard let newerPageID = UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
              let olderPageID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") else {
            XCTFail("UUID の文字列を読めませんでした")
            return
        }
        let (store, context, _) = try makeStore()
        let dateKey = "2026-10-27"
        // 新しい方を先に入れる。古い方は id の文字順が大きい。時刻で古い方が選ばれる。
        _ = insertDailyPair(
            in: context,
            id: newerPageID,
            dateKey: dateKey,
            monthKey: "2026-10",
            createdAt: Date(timeIntervalSince1970: 2_000),
            memo: "新しい"
        )
        let olderDaily = insertDailyPair(
            in: context,
            id: olderPageID,
            dateKey: dateKey,
            monthKey: "2026-10",
            createdAt: Date(timeIntervalSince1970: 1_000),
            memo: "古い"
        )
        try context.save()

        let found = try store.findDaily(dateKey: dateKey)
        XCTAssertEqual(found?.id, olderDaily.id)
        XCTAssertEqual(found?.memo, "古い")

        let again = try store.findOrCreateDaily(dateKey: dateKey, createdBy: .carryOver)
        XCTAssertEqual(again.id, olderDaily.id)
        XCTAssertEqual(again.memo, "古い")
        let storedPages = try context.fetch(FetchDescriptor<Page>())
        XCTAssertTrue(storedPages.allSatisfy { page in
            page.createdByRaw == PageCreatedBy.user.rawValue
        })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertEqual(try countPages(kindRaw: PageKind.daily.rawValue, in: context), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 2)
    }

    /// 同じ日で、作った時刻も同じ目次カードが2つのときは、id の文字順が小さい方。
    func testDuplicateDailySameTimeReturnsSmallerPageID() throws {
        guard let smallerID = UUID(uuidString: "00000000-0000-0000-0000-00000000000A"),
              let largerID = UUID(uuidString: "00000000-0000-0000-0000-00000000000B") else {
            XCTFail("UUID の文字列を読めませんでした")
            return
        }
        XCTAssertLessThan(smallerID.uuidString, largerID.uuidString)

        let (store, context, _) = try makeStore()
        let sameTime = Date(timeIntervalSince1970: 1_700_000_000)
        // 文字順が大きい方を先に入れる。同時刻なら、小さい id が選ばれる。
        _ = insertDailyPair(
            in: context,
            id: largerID,
            dateKey: "2026-10-27",
            monthKey: "2026-10",
            createdAt: sameTime,
            memo: "大きいid"
        )
        let smallerDaily = insertDailyPair(
            in: context,
            id: smallerID,
            dateKey: "2026-10-27",
            monthKey: "2026-10",
            createdAt: sameTime,
            memo: "小さいid"
        )
        try context.save()

        let found = try store.findDaily(dateKey: "2026-10-27")
        XCTAssertEqual(found?.id, smallerDaily.id)
        XCTAssertEqual(found?.memo, "小さいid")
        XCTAssertEqual(found?.page?.id, smallerID)

        let again = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .system)
        XCTAssertEqual(again.id, smallerDaily.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 2)
    }

    /// 日の目次カードだけで中身が無いとき、中身を1つ足す。Page は増えない。
    func testBrokenDailyPageReceivesContentWithoutNewPage() throws {
        let (store, context, _) = try makeStore()
        let page = Page(
            kindRaw: PageKind.daily.rawValue,
            dateKey: "2026-10-27",
            monthKey: "2026-10",
            createdByRaw: PageCreatedBy.system.rawValue
        )
        context.insert(page)
        try context.save()

        XCTAssertNil(try store.findDaily(dateKey: "2026-10-27"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 1)

        let daily = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .carryOver)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 1)
        XCTAssertEqual(try countPages(kindRaw: PageKind.daily.rawValue, in: context), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)
        XCTAssertEqual(daily.id, page.daily?.id)
        XCTAssertEqual(daily.dateKey, "2026-10-27")
        XCTAssertEqual(page.createdBy, .system)
        XCTAssertEqual(page.createdByRaw, "system")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 0)
    }

    /// 月の目次カードだけで中身が無いとき、中身を1つ足す。Page は増えない。
    func testBrokenMonthlyPageReceivesContentWithoutNewPage() throws {
        let (store, context, _) = try makeStore()
        let page = Page(
            kindRaw: PageKind.monthly.rawValue,
            dateKey: nil,
            monthKey: "2026-10",
            createdByRaw: PageCreatedBy.user.rawValue
        )
        context.insert(page)
        try context.save()

        XCTAssertNil(try store.findMonthly(monthKey: "2026-10"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 1)

        let monthly = try store.findOrCreateMonthly(monthKey: "2026-10")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 1)
        XCTAssertEqual(monthly.id, page.monthly?.id)
        XCTAssertEqual(monthly.monthKey, "2026-10")
        XCTAssertEqual(page.createdBy, .user)
        XCTAssertEqual(page.createdByRaw, "user")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0)
        XCTAssertEqual(try store.findMonthly(monthKey: "2026-10")?.id, monthly.id)
    }

    /// 作ったあとに保存されている。別の読み書き窓口から見える。
    func testSavedDailyIsVisibleFromAnotherContext() throws {
        let (store, context, container) = try makeStore()
        _ = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .carryOver)

        let firstPages = try context.fetch(FetchDescriptor<Page>())
        let dailyIndex = firstPages.first { page in
            page.kindRaw == PageKind.daily.rawValue
        }
        let monthlyIndex = firstPages.first { page in
            page.kindRaw == PageKind.monthly.rawValue
        }
        let dailyID = dailyIndex?.daily?.id
        XCTAssertNotNil(dailyID)
        XCTAssertNotNil(dailyIndex?.id)
        XCTAssertNotNil(monthlyIndex?.id)

        let other = ModelContext(container)
        let dailies = try other.fetch(FetchDescriptor<DailyPage>())
        XCTAssertEqual(dailies.count, 1)
        XCTAssertEqual(dailies.first?.id, dailyID)
        XCTAssertEqual(dailies.first?.dateKey, "2026-10-27")

        let pages = try other.fetch(FetchDescriptor<Page>())
        XCTAssertEqual(pages.count, 2)
        let savedDaily = pages.first { page in
            page.id == dailyIndex?.id
        }
        XCTAssertEqual(savedDaily?.createdByRaw, "carryOver")
        XCTAssertEqual(savedDaily?.dateKey, "2026-10-27")
        XCTAssertEqual(savedDaily?.monthKey, "2026-10")
        XCTAssertEqual(savedDaily?.kindRaw, "daily")

        let monthlies = try other.fetch(FetchDescriptor<MonthlyPage>())
        XCTAssertEqual(monthlies.count, 1)
        XCTAssertEqual(monthlies.first?.monthKey, "2026-10")

        let links = try other.fetch(FetchDescriptor<PageLink>())
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.fromPageID, dailyIndex?.id)
        XCTAssertEqual(links.first?.toPageID, monthlyIndex?.id)
        XCTAssertEqual(links.first?.typeRaw, "dailyToMonthly")

        let journals = try other.fetch(FetchDescriptor<Journal>())
        XCTAssertEqual(journals.count, 1)
    }

    /// 最古の日ページは中身が無く、新しい重複には中身がある。新しい方を返す。
    func testNewerDuplicateWithContentIsChosenWhenOldestDailyIsBroken() throws {
        guard let newerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
              let olderID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") else {
            XCTFail("UUID の文字列を読めませんでした")
            return
        }
        let (store, context, _) = try makeStore()
        let dateKey = "2026-10-27"
        // 中身がある新しい方を先に入れる。壊れた古い方は、時刻は古く、id の文字順は大きい。
        let newerDaily = insertDailyPair(
            in: context,
            id: newerID,
            dateKey: dateKey,
            monthKey: "2026-10",
            createdAt: Date(timeIntervalSince1970: 2_000),
            memo: "中身あり"
        )
        let broken = Page(
            id: olderID,
            kindRaw: PageKind.daily.rawValue,
            dateKey: dateKey,
            monthKey: "2026-10",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        context.insert(broken)
        try context.save()

        let found = try store.findDaily(dateKey: dateKey)
        XCTAssertEqual(found?.id, newerDaily.id)
        XCTAssertEqual(found?.memo, "中身あり")

        let again = try store.findOrCreateDaily(dateKey: dateKey, createdBy: .user)
        XCTAssertEqual(again.id, newerDaily.id)
        XCTAssertEqual(again.memo, "中身あり")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 2)
        XCTAssertNil(broken.daily)
    }

    /// 中身がある月が2つのとき、日の PageLink は、その中で一番古い月へ張る。
    func testFindOrCreateDailyLinksToOldestMonthlyThatHasContent() throws {
        guard let newerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
              let olderID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") else {
            XCTFail("UUID の文字列を読めませんでした")
            return
        }
        let (store, context, _) = try makeStore()
        // 新しい方を先に入れる。古い方は id の文字順が大きい。どちらも中身がある。
        let newerPage = insertMonthlyPair(
            in: context,
            id: newerID,
            monthKey: "2026-10",
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let olderPage = insertMonthlyPair(
            in: context,
            id: olderID,
            monthKey: "2026-10",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        try context.save()

        let daily = try store.findOrCreateDaily(dateKey: "2026-10-27", createdBy: .user)
        let links = try context.fetch(FetchDescriptor<PageLink>())
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.typeRaw, "dailyToMonthly")
        XCTAssertEqual(links.first?.toPageID, olderPage.id)
        XCTAssertEqual(links.first?.toPageID, olderID)
        XCTAssertNotEqual(links.first?.toPageID, newerPage.id)
        XCTAssertEqual(links.first?.fromPageID, daily.page?.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 2)
        XCTAssertEqual(try countPages(kindRaw: PageKind.monthly.rawValue, in: context), 2)
        XCTAssertEqual(try countPages(kindRaw: PageKind.daily.rawValue, in: context), 1)
    }

    // MARK: - ヘルパー

    private func makeStore() throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = JournalStore(context: context)
        return (store, context, container)
    }

    private func countPages(kindRaw: String, in context: ModelContext) throws -> Int {
        let pages = try context.fetch(FetchDescriptor<Page>())
        return pages.filter { page in
            page.kindRaw == kindRaw
        }.count
    }

    private func assertNothingStored(
        in context: ModelContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 0, file: file, line: line)
    }

    @discardableResult
    private func insertDailyPair(
        in context: ModelContext,
        id: UUID = UUID(),
        dateKey: String,
        monthKey: String,
        createdAt: Date,
        memo: String
    ) -> DailyPage {
        let page = Page(
            id: id,
            kindRaw: PageKind.daily.rawValue,
            dateKey: dateKey,
            monthKey: monthKey,
            createdAt: createdAt
        )
        let daily = DailyPage(
            dateKey: dateKey,
            memo: memo
        )
        context.insert(page)
        context.insert(daily)
        page.daily = daily
        return daily
    }

    @discardableResult
    private func insertMonthlyPair(
        in context: ModelContext,
        id: UUID = UUID(),
        monthKey: String,
        createdAt: Date
    ) -> Page {
        let page = Page(
            id: id,
            kindRaw: PageKind.monthly.rawValue,
            dateKey: nil,
            monthKey: monthKey,
            createdAt: createdAt
        )
        let monthly = MonthlyPage(monthKey: monthKey)
        context.insert(page)
        context.insert(monthly)
        page.monthly = monthly
        return page
    }
}
