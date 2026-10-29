import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// 月の読み出し。メモリ上の保存だけ。App Group は使わない。読むだけで、件数は増えない。
final class JournalStoreMonthlyLogTests: XCTestCase {
    /// 見本の 2026-10 は、1行の文章と Daily がある日が見本どおり。
    func testSampleOctoberLinesAndDailies() throws {
        let (store, context, _) = try makeStore()
        try SampleData.install(into: store, context: context)
        let before = try recordCounts(in: context)

        let content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(content.textByDateKey, expectedOctoberLines())
        XCTAssertEqual(content.textByDateKey.count, 20)
        XCTAssertNil(content.textByDateKey["2026-10-05"])
        XCTAssertNil(content.textByDateKey["2026-10-27"])
        XCTAssertEqual(content.textByDateKey["2026-10-01"], "月初")
        XCTAssertEqual(content.textByDateKey["2026-10-31"], "月末。October ends.")
        XCTAssertEqual(
            content.dailyDateKeys,
            Set([
                "2026-10-01",
                "2026-10-05",
                "2026-10-12",
                "2026-10-20",
                "2026-10-21",
                "2026-10-27",
                "2026-10-31",
            ])
        )
        XCTAssertFalse(content.dailyDateKeys.contains("2026-10-03"))
        XCTAssertEqual(try recordCounts(in: context), before)
    }

    /// 月ページが無い月を読んでも、ページも行も増えない。結果は空。
    func testMissingMonthDoesNotCreateRecords() throws {
        let (store, context, _) = try makeStore()
        try SampleData.install(into: store, context: context)
        let before = try recordCounts(in: context)

        let content = try store.monthlyLogContent(monthKey: "2026-11")
        XCTAssertTrue(content.textByDateKey.isEmpty)
        XCTAssertTrue(content.dailyDateKeys.isEmpty)
        XCTAssertEqual(try recordCounts(in: context), before)

        let emptyStore = try makeStore()
        let emptyBefore = try recordCounts(in: emptyStore.context)
        let emptyContent = try emptyStore.store.monthlyLogContent(monthKey: "2026-11")
        XCTAssertTrue(emptyContent.textByDateKey.isEmpty)
        XCTAssertTrue(emptyContent.dailyDateKeys.isEmpty)
        XCTAssertEqual(try recordCounts(in: emptyStore.context), emptyBefore)
    }

    /// 同じ日が2件あるときは、更新時刻が新しい方。月の外の行は無視する。
    func testSameDayPrefersNewerLine() throws {
        let olderID = try uuid("00000000-0000-0000-0000-00000000000B")
        let newerID = try uuid("00000000-0000-0000-0000-00000000000A")
        XCTAssertGreaterThan(olderID.uuidString, newerID.uuidString)
        let (store, context, _) = try makeStore()
        let monthly = try store.findOrCreateMonthly(monthKey: "2026-10")
        let older = MonthlyLogLine(
            id: olderID,
            dateKey: "2026-10-03",
            text: "古い",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = MonthlyLogLine(
            id: newerID,
            dateKey: "2026-10-03",
            text: "新しい",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let outside = MonthlyLogLine(
            dateKey: "2026-11-01",
            text: "来月",
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let broken = MonthlyLogLine(
            dateKey: "nope",
            text: "壊れた",
            updatedAt: Date(timeIntervalSince1970: 4_000)
        )
        context.insert(older)
        context.insert(newer)
        context.insert(outside)
        context.insert(broken)
        older.monthly = monthly
        newer.monthly = monthly
        outside.monthly = monthly
        broken.monthly = monthly
        try context.save()
        let before = try recordCounts(in: context)

        let content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(content.textByDateKey["2026-10-03"], "新しい")
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-03")?.text, "新しい")
        XCTAssertNil(content.textByDateKey["2026-11-01"])
        XCTAssertNil(content.textByDateKey["nope"])
        XCTAssertEqual(content.textByDateKey.count, 1)
        XCTAssertEqual(try recordCounts(in: context), before)
    }

    /// 更新時刻が同じ2件は、id の文字順が大きい方。
    func testSameTimePrefersLargerID() throws {
        let smallerID = try uuid("00000000-0000-0000-0000-00000000000A")
        let largerID = try uuid("00000000-0000-0000-0000-00000000000B")
        XCTAssertLessThan(smallerID.uuidString, largerID.uuidString)
        let (store, context, _) = try makeStore()
        let monthly = try store.findOrCreateMonthly(monthKey: "2026-10")
        let sameTime = Date(timeIntervalSince1970: 5_000)
        let smaller = MonthlyLogLine(
            id: smallerID,
            dateKey: "2026-10-27",
            text: "小さい",
            updatedAt: sameTime
        )
        let larger = MonthlyLogLine(
            id: largerID,
            dateKey: "2026-10-27",
            text: "大きい",
            updatedAt: sameTime
        )
        context.insert(smaller)
        context.insert(larger)
        smaller.monthly = monthly
        larger.monthly = monthly
        try context.save()

        let content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(content.textByDateKey["2026-10-27"], "大きい")
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-27")?.id, largerID)
        XCTAssertEqual(content.textByDateKey.count, 1)
    }

    /// setLogLine で書いた文字が、その月の読み出しに出る。書き換えと、空にして消すことも含む。
    func testSetLogLineAppearsThenUpdatesThenDeletes() throws {
        let (store, _, _) = try makeStore()

        try store.setLogLine(dateKey: "2026-10-27", text: "書いた")
        var content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(content.textByDateKey["2026-10-27"], "書いた")
        XCTAssertEqual(content.textByDateKey.count, 1)

        try store.setLogLine(dateKey: "2026-10-27", text: "書き換えた")
        content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(content.textByDateKey["2026-10-27"], "書き換えた")
        XCTAssertNil(content.textByDateKey["2026-10-28"])
        XCTAssertEqual(content.textByDateKey.count, 1)

        try store.setLogLine(dateKey: "2026-10-27", text: "  空白つき  ")
        content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(content.textByDateKey["2026-10-27"], "  空白つき  ")

        try store.setLogLine(dateKey: "2026-10-27", text: "")
        content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertNil(content.textByDateKey["2026-10-27"])
        XCTAssertTrue(content.textByDateKey.isEmpty)
        XCTAssertNil(try store.logLine(dateKey: "2026-10-27"))
    }

    /// ほかの月の行は、その月の結果に入らない。同じ「日」でも混ざらない。
    /// ページが無い月を読んでも、何も作らない。
    func testLinesFromAnotherMonthStayOut() throws {
        let (store, context, _) = try makeStore()
        try store.setLogLine(dateKey: "2026-10-03", text: "十月の3日")
        try store.setLogLine(dateKey: "2026-11-03", text: "十一月の3日")
        try store.setLogLine(dateKey: "2026-10-04", text: "十月の4日")

        let october = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(october.textByDateKey["2026-10-03"], "十月の3日")
        XCTAssertEqual(october.textByDateKey["2026-10-04"], "十月の4日")
        XCTAssertNil(october.textByDateKey["2026-11-03"])
        XCTAssertFalse(october.textByDateKey.values.contains("十一月の3日"))
        XCTAssertEqual(october.textByDateKey.count, 2)
        XCTAssertTrue(october.dailyDateKeys.isEmpty)

        let november = try store.monthlyLogContent(monthKey: "2026-11")
        XCTAssertEqual(november.textByDateKey["2026-11-03"], "十一月の3日")
        XCTAssertNil(november.textByDateKey["2026-10-03"])
        XCTAssertNil(november.textByDateKey["2026-10-04"])
        XCTAssertEqual(november.textByDateKey.count, 1)
        XCTAssertTrue(november.dailyDateKeys.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 3)

        let beforeUnreadMonth = try recordCounts(in: context)
        let december = try store.monthlyLogContent(monthKey: "2026-12")
        XCTAssertTrue(december.textByDateKey.isEmpty)
        XCTAssertTrue(december.dailyDateKeys.isEmpty)
        XCTAssertEqual(try recordCounts(in: context), beforeUnreadMonth)
    }

    /// 空白だけの入力は、行を作らない。すでにある行は消す。
    func testWhitespaceOnlyRemovesOrSkipsLine() throws {
        let (store, context, _) = try makeStore()
        let before = try recordCounts(in: context)

        try store.setLogLine(dateKey: "2026-10-08", text: "   ")
        try store.setLogLine(dateKey: "2026-10-08", text: "\n")
        try store.setLogLine(dateKey: "2026-10-08", text: " \n\t ")
        var content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertTrue(content.textByDateKey.isEmpty)
        XCTAssertEqual(try recordCounts(in: context), before)

        try store.setLogLine(dateKey: "2026-10-08", text: "残す")
        content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertEqual(content.textByDateKey["2026-10-08"], "残す")

        try store.setLogLine(dateKey: "2026-10-08", text: "  \n ")
        content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertNil(content.textByDateKey["2026-10-08"])
        XCTAssertTrue(content.textByDateKey.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0)
    }

    /// Daily の印は、中身がある日だけ。別の月の Daily は入らない。空の目次カードは入らない。
    func testDailyMarkNeedsContentAndStaysInMonth() throws {
        let (store, context, _) = try makeStore()
        _ = try store.findOrCreateMonthly(monthKey: "2026-10")
        _ = try store.findOrCreateDaily(dateKey: "2026-10-01", createdBy: .user)
        _ = try store.findOrCreateDaily(dateKey: "2026-09-30", createdBy: .user)
        let emptyCard = Page(
            kindRaw: PageKind.daily.rawValue,
            dateKey: "2026-10-02",
            monthKey: "2026-10",
            createdByRaw: PageCreatedBy.user.rawValue
        )
        context.insert(emptyCard)
        try context.save()
        let before = try recordCounts(in: context)

        let content = try store.monthlyLogContent(monthKey: "2026-10")
        XCTAssertTrue(content.dailyDateKeys.contains("2026-10-01"))
        XCTAssertFalse(content.dailyDateKeys.contains("2026-10-02"))
        XCTAssertFalse(content.dailyDateKeys.contains("2026-09-30"))
        XCTAssertEqual(content.dailyDateKeys, Set(["2026-10-01"]))
        XCTAssertTrue(content.textByDateKey.isEmpty)
        XCTAssertEqual(try recordCounts(in: context), before)
    }

    private func makeStore() throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = JournalStore(
            context: context,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        return (store, context, container)
    }

    private func recordCounts(in context: ModelContext) throws -> RecordCounts {
        let pageCount = try context.fetchCount(FetchDescriptor<Page>())
        let monthlyCount = try context.fetchCount(FetchDescriptor<MonthlyPage>())
        let dailyCount = try context.fetchCount(FetchDescriptor<DailyPage>())
        let lineCount = try context.fetchCount(FetchDescriptor<MonthlyLogLine>())
        return RecordCounts(
            page: pageCount,
            monthly: monthlyCount,
            daily: dailyCount,
            line: lineCount
        )
    }

    private func uuid(_ text: String) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: text))
    }

    /// 見本の1行。無い日は入れない。実装が違う文字を返すと落ちる。
    private func expectedOctoberLines() -> [String: String] {
        [
            "2026-10-01": "月初",
            "2026-10-02": "Review the October plan 2026",
            "2026-10-03": "土曜の散歩 🚶",
            "2026-10-04": "日曜は休む",
            "2026-10-06": "メモ",
            "2026-10-07": "ABC123",
            "2026-10-08": "きょうは窓を開けて、長い文章が折り返されるかを見るための記録を書いておく。画面の端まで続く一行です。",
            "2026-10-09": "会議",
            "2026-10-10": "洗濯",
            "2026-10-11": "読書",
            "2026-10-13": "コーヒー",
            "2026-10-14": "買い物",
            "2026-10-15": "Mid-month note",
            "2026-10-16": "散歩",
            "2026-10-17": "手紙を書く",
            "2026-10-18": "短",
            "2026-10-21": "週の始まり",
            "2026-10-24": "資料",
            "2026-10-28": "振り返り前",
            "2026-10-31": "月末。October ends.",
        ]
    }
}

/// ページと行の件数。タプルは Equatable になれないので、比較はこの構造体で行う。
private struct RecordCounts: Equatable {
    let page: Int
    let monthly: Int
    let daily: Int
    let line: Int
}
