import Foundation
import SwiftData
import XCTest
@testable import EasyJournal

/// 日ごとの記録（1行、気分、睡眠、習慣のチェック）。メモリ上の保存だけ。
final class JournalStoreRecordsTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    /// 1行を作る。同じ日は上書きで1件のまま。前後の空白は残す。月ページは自動でできる。日ページはできない。
    func testSetLogLineCreatesAndOverwritesWithoutTrimming() throws {
        let (store, context, _) = try makeStore()
        try store.setLogLine(dateKey: "2026-10-27", text: "  そのまま  ")

        var lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.text, "  そのまま  ")
        XCTAssertEqual(lines.first?.dateKey, "2026-10-27")
        XCTAssertEqual(lines.first?.updatedAt, fixedNow)
        XCTAssertEqual(lines.first?.monthly?.monthKey, "2026-10")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 1)

        try store.setLogLine(dateKey: "2026-10-27", text: "次の文")
        lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.text, "次の文")
        XCTAssertEqual(lines.first?.updatedAt, fixedNow)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0)
    }

    /// 空や空白だけなら行を消す。最初から無い日を空で消しても、何も作らない。
    func testSetLogLineBlankDeletesAndMissingBlankCreatesNothing() throws {
        let (store, context, container) = try makeStore()
        try store.setLogLine(dateKey: "2026-10-27", text: "")
        try store.setLogLine(dateKey: "2026-10-27", text: "   ")
        try store.setLogLine(dateKey: "2026-10-27", text: "\n")
        try store.setLogLine(dateKey: "2026-10-27", text: " \n\t ")
        try assertNoStoredRecords(in: context)

        try store.setLogLine(dateKey: "2026-10-27", text: "残す")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 1)
        try store.setLogLine(dateKey: "2026-10-27", text: " ")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)

        let other = ModelContext(container)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0)
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
    }

    /// 不正な日付では、何も作らない。
    func testSetLogLineInvalidDateKeyCreatesNothing() throws {
        let (store, context, _) = try makeStore()
        let invalidKeys = ["2026-02-30", "2026-1-5", ""]
        for invalidKey in invalidKeys {
            XCTAssertThrowsError(try store.setLogLine(dateKey: invalidKey, text: "書かない")) { error in
                XCTAssertEqual(error as? JournalStoreError, .invalidDayKey(invalidKey))
            }
        }
        try assertNoStoredRecords(in: context)
    }

    /// 別の日は、別の行。同じ月の月ページは1枚。
    func testSetLogLineDifferentDaysAreSeparateLines() throws {
        let (store, context, _) = try makeStore()
        try store.setLogLine(dateKey: "2026-10-27", text: "27日")
        try store.setLogLine(dateKey: "2026-10-28", text: "28日")

        let lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 2)
        let day27 = lines.filter { line in
            line.dateKey == "2026-10-27"
        }
        let day28 = lines.filter { line in
            line.dateKey == "2026-10-28"
        }
        XCTAssertEqual(day27.count, 1)
        XCTAssertEqual(day27.first?.text, "27日")
        XCTAssertEqual(day28.count, 1)
        XCTAssertEqual(day28.first?.text, "28日")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 1)
        XCTAssertTrue(lines.allSatisfy { line in
            line.monthly?.monthKey == "2026-10"
        })
    }

    /// 同じ日が2件あるとき、更新時刻が新しい方だけを書き換える。古い方は残す。
    ///
    /// 新しい方の id の文字順は、古い方より小さい。時刻で選んでいることを見る。
    func testSetLogLineDuplicateUpdatesLatest() throws {
        guard let olderID = uuid("00000000-0000-0000-0000-00000000000B"),
              let newerID = uuid("00000000-0000-0000-0000-00000000000A") else {
            return
        }
        XCTAssertGreaterThan(olderID.uuidString, newerID.uuidString)
        let (store, context, _) = try makeStore()
        let older = MonthlyLogLine(
            id: olderID,
            dateKey: "2026-10-27",
            text: "古い",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = MonthlyLogLine(
            id: newerID,
            dateKey: "2026-10-27",
            text: "新しい",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        context.insert(newer)
        context.insert(older)
        try context.save()

        XCTAssertEqual(try store.logLine(dateKey: "2026-10-27")?.id, newerID)
        try store.setLogLine(dateKey: "2026-10-27", text: "更新")
        let lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 2)
        let storedOlder = lines.first { line in
            line.id == olderID
        }
        let storedNewer = lines.first { line in
            line.id == newerID
        }
        XCTAssertEqual(storedNewer?.text, "更新")
        XCTAssertEqual(storedNewer?.updatedAt, fixedNow)
        XCTAssertEqual(storedOlder?.text, "古い")
        XCTAssertEqual(storedOlder?.updatedAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-27")?.id, newerID)
    }

    /// 更新時刻が同じ2件は、id の文字順が大きい方を書き換える。
    func testSetLogLineDuplicateSameTimeUpdatesLargerID() throws {
        guard let smallerID = uuid("00000000-0000-0000-0000-00000000000A"),
              let largerID = uuid("00000000-0000-0000-0000-00000000000B") else {
            return
        }
        XCTAssertLessThan(smallerID.uuidString, largerID.uuidString)
        let (store, context, _) = try makeStore()
        let sameTime = Date(timeIntervalSince1970: 5_000)
        let larger = MonthlyLogLine(
            id: largerID,
            dateKey: "2026-10-27",
            text: "大きい",
            updatedAt: sameTime
        )
        let smaller = MonthlyLogLine(
            id: smallerID,
            dateKey: "2026-10-27",
            text: "小さい",
            updatedAt: sameTime
        )
        context.insert(larger)
        context.insert(smaller)
        try context.save()

        XCTAssertEqual(try store.logLine(dateKey: "2026-10-27")?.id, largerID)
        try store.setLogLine(dateKey: "2026-10-27", text: "選ばれた")
        let lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 2)
        let storedSmaller = lines.first { line in
            line.id == smallerID
        }
        let storedLarger = lines.first { line in
            line.id == largerID
        }
        XCTAssertEqual(storedLarger?.text, "選ばれた")
        XCTAssertEqual(storedSmaller?.text, "小さい")
        XCTAssertEqual(storedSmaller?.updatedAt, sameTime)
    }

    /// 空文字で消すときは、その日の行を全部消す。別の日は残す。月ページは作らない。
    func testSetLogLineBlankDeletesAllDuplicates() throws {
        guard let olderID = uuid("00000000-0000-0000-0000-00000000000B"),
              let newerID = uuid("00000000-0000-0000-0000-00000000000A") else {
            return
        }
        let (store, context, _) = try makeStore()
        let older = MonthlyLogLine(
            id: olderID,
            dateKey: "2026-10-27",
            text: "古い",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = MonthlyLogLine(
            id: newerID,
            dateKey: "2026-10-27",
            text: "新しい",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let otherDay = MonthlyLogLine(
            dateKey: "2026-10-28",
            text: "別の日",
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        context.insert(older)
        context.insert(newer)
        context.insert(otherDay)
        try context.save()

        try store.setLogLine(dateKey: "2026-10-27", text: " \n ")
        let lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.dateKey, "2026-10-28")
        XCTAssertEqual(lines.first?.text, "別の日")
        XCTAssertNil(try store.logLine(dateKey: "2026-10-27"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0)
    }

    /// 気分を作り、上書きし、nil で消す。日ページは作らない。不正な日付では消さない。
    func testSetMoodCreatesUpdatesDeletesAndSkipsDaily() throws {
        let (store, context, _) = try makeStore()
        XCTAssertThrowsError(try store.setMood(dateKey: "2026-02-30", level: 3)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey("2026-02-30"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0)

        try store.setMood(dateKey: "2026-10-27", level: 1)
        var moods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.level, 1)
        XCTAssertEqual(moods.first?.dateKey, "2026-10-27")
        XCTAssertEqual(moods.first?.updatedAt, fixedNow)
        XCTAssertNil(moods.first?.note)
        try assertNoPage(in: context)

        XCTAssertThrowsError(try store.setMood(dateKey: "2026-02-30", level: nil)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey("2026-02-30"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 1)

        try store.setMood(dateKey: "2026-10-27", level: 5)
        moods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.level, 5)
        XCTAssertEqual(moods.first?.updatedAt, fixedNow)

        try store.setMood(dateKey: "2026-10-27", level: nil)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0)
        try store.setMood(dateKey: "2026-10-27", level: nil)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0)
        try assertNoPage(in: context)
    }

    /// 0 と 6 はエラー。保存しない。すでに書いてある気分も変えない。
    func testSetMoodRejectsOutOfRangeAndSavesNothing() throws {
        let (store, context, _) = try makeStore()
        XCTAssertThrowsError(try store.setMood(dateKey: "2026-10-27", level: 0)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidMoodLevel(0))
        }
        XCTAssertThrowsError(try store.setMood(dateKey: "2026-10-27", level: 6)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidMoodLevel(6))
        }
        try assertNoStoredRecords(in: context)

        try store.setMood(dateKey: "2026-10-27", level: 3)
        XCTAssertThrowsError(try store.setMood(dateKey: "2026-10-27", level: 0)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidMoodLevel(0))
        }
        XCTAssertThrowsError(try store.setMood(dateKey: "2026-10-27", level: 6)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidMoodLevel(6))
        }
        let moods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.level, 3)
        try assertNoPage(in: context)
    }

    /// 睡眠を作る（0.5）し、24 に上書きし、nil で消す。日ページは作らない。
    func testSetSleepCreatesUpdatesDeletesAndSkipsDaily() throws {
        let (store, context, _) = try makeStore()
        XCTAssertThrowsError(try store.setSleep(dateKey: "2026-02-30", hours: 8)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey("2026-02-30"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 0)

        try store.setSleep(dateKey: "2026-10-27", hours: 0.5)
        var sleeps = try context.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(sleeps.first?.hours, 0.5)
        XCTAssertEqual(sleeps.first?.dateKey, "2026-10-27")
        XCTAssertEqual(sleeps.first?.updatedAt, fixedNow)
        XCTAssertNil(sleeps.first?.quality)
        try assertNoPage(in: context)

        XCTAssertThrowsError(try store.setSleep(dateKey: "", hours: nil)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey(""))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 1)

        try store.setSleep(dateKey: "2026-10-27", hours: 24.0)
        sleeps = try context.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(sleeps.first?.hours, 24.0)
        XCTAssertEqual(sleeps.first?.updatedAt, fixedNow)

        try store.setSleep(dateKey: "2026-10-27", hours: nil)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 0)
        try store.setSleep(dateKey: "2026-10-27", hours: nil)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 0)
        try assertNoPage(in: context)
    }

    /// 0、24.5、0.5 きざみでない 7.3 はエラー。何も足さない。すでにある記録も変えない。
    func testSetSleepRejectsInvalidHours() throws {
        let (store, context, _) = try makeStore()
        let tooSmall = 0.0
        let tooBig = 24.5
        let offStep = 7.3
        XCTAssertThrowsError(try store.setSleep(dateKey: "2026-10-27", hours: tooSmall)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidSleepHours(tooSmall))
        }
        XCTAssertThrowsError(try store.setSleep(dateKey: "2026-10-27", hours: tooBig)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidSleepHours(tooBig))
        }
        XCTAssertThrowsError(try store.setSleep(dateKey: "2026-10-27", hours: offStep)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidSleepHours(offStep))
        }
        try assertNoStoredRecords(in: context)

        try store.setSleep(dateKey: "2026-10-27", hours: 8.0)
        XCTAssertThrowsError(try store.setSleep(dateKey: "2026-10-27", hours: offStep)) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidSleepHours(offStep))
        }
        let sleeps = try context.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(sleeps.first?.hours, 8.0)
        try assertNoPage(in: context)
    }

    /// 1回目でチェックが付き true。2回目で消えて false。別の日は残る。日ページはできない。
    func testToggleHabitTurnsOnThenOffAndKeepsOtherDays() throws {
        let (store, context, _) = try makeStore()
        let habit = Habit(name: "ストレッチ", shortLabel: "伸")
        context.insert(habit)
        try context.save()

        let turnedOn = try store.toggleHabit(habitID: habit.id, dateKey: "2026-10-27")
        XCTAssertTrue(turnedOn)
        var entries = try context.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.habitID, habit.id)
        XCTAssertEqual(entries.first?.dateKey, "2026-10-27")
        XCTAssertEqual(entries.first?.isDone, true)
        XCTAssertEqual(entries.first?.updatedAt, fixedNow)
        try assertNoPage(in: context)

        let otherDay = try store.toggleHabit(habitID: habit.id, dateKey: "2026-10-28")
        XCTAssertTrue(otherDay)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 2)

        let turnedOff = try store.toggleHabit(habitID: habit.id, dateKey: "2026-10-27")
        XCTAssertFalse(turnedOff)
        entries = try context.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.dateKey, "2026-10-28")
        XCTAssertEqual(entries.first?.habitID, habit.id)
        try assertNoPage(in: context)
    }

    /// 日付が不正なら、習慣が無くても invalidDayKey。習慣が無いと habitNotFound。記録は増えない。
    func testToggleHabitRejectsMissingHabitAndInvalidDate() throws {
        let (store, context, _) = try makeStore()
        let missing = UUID()
        XCTAssertThrowsError(try store.toggleHabit(habitID: missing, dateKey: "2026-02-30")) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey("2026-02-30"))
        }
        XCTAssertThrowsError(try store.toggleHabit(habitID: missing, dateKey: "2026-10-27")) { error in
            XCTAssertEqual(error as? JournalStoreError, .habitNotFound(missing))
        }
        try assertNoStoredRecords(in: context)

        let habit = Habit(name: "読書", shortLabel: "読")
        context.insert(habit)
        try context.save()
        XCTAssertThrowsError(try store.toggleHabit(habitID: habit.id, dateKey: "")) { error in
            XCTAssertEqual(error as? JournalStoreError, .invalidDayKey(""))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 0)
        try assertNoPage(in: context)
    }

    /// 同じ習慣・同じ日が複数あるときは、全部消して false。別の習慣は残す。
    func testToggleHabitDeletesAllDuplicates() throws {
        let (store, context, _) = try makeStore()
        let target = Habit(name: "水", shortLabel: "水")
        let other = Habit(name: "散歩", shortLabel: "歩")
        context.insert(target)
        context.insert(other)
        let first = HabitEntry(
            habitID: target.id,
            dateKey: "2026-10-27",
            isDone: true,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let second = HabitEntry(
            habitID: target.id,
            dateKey: "2026-10-27",
            isDone: true,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let kept = HabitEntry(
            habitID: other.id,
            dateKey: "2026-10-27",
            isDone: true,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        context.insert(first)
        context.insert(second)
        context.insert(kept)
        try context.save()

        let turnedOff = try store.toggleHabit(habitID: target.id, dateKey: "2026-10-27")
        XCTAssertFalse(turnedOff)
        let entries = try context.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.habitID, other.id)
        XCTAssertEqual(entries.first?.dateKey, "2026-10-27")
    }

    /// 別の読み書き窓口から、保存した記録が見える。消した記録は見えず、消していない睡眠は残る。
    func testSavedRecordsAreVisibleFromAnotherContext() throws {
        let (store, context, container) = try makeStore()
        try store.setLogLine(dateKey: "2026-10-27", text: "一行")
        try store.setMood(dateKey: "2026-10-28", level: 4)
        try store.setSleep(dateKey: "2026-10-29", hours: 7.5)
        let habit = Habit(name: "散歩", shortLabel: "歩")
        context.insert(habit)
        try context.save()
        let turnedOn = try store.toggleHabit(habitID: habit.id, dateKey: "2026-10-30")
        XCTAssertTrue(turnedOn)

        let other = ModelContext(container)
        let lines = try other.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.text, "一行")
        XCTAssertEqual(lines.first?.dateKey, "2026-10-27")

        let moods = try other.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.level, 4)
        XCTAssertEqual(moods.first?.dateKey, "2026-10-28")

        let sleeps = try other.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(sleeps.first?.hours, 7.5)
        XCTAssertEqual(sleeps.first?.dateKey, "2026-10-29")

        let entries = try other.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.habitID, habit.id)
        XCTAssertEqual(entries.first?.dateKey, "2026-10-30")
        XCTAssertEqual(entries.first?.isDone, true)

        try store.setMood(dateKey: "2026-10-28", level: nil)
        try store.setLogLine(dateKey: "2026-10-27", text: " ")
        let turnedOff = try store.toggleHabit(habitID: habit.id, dateKey: "2026-10-30")
        XCTAssertFalse(turnedOff)

        let after = ModelContext(container)
        XCTAssertEqual(try after.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0)
        XCTAssertEqual(try after.fetchCount(FetchDescriptor<MoodEntry>()), 0)
        XCTAssertEqual(try after.fetchCount(FetchDescriptor<HabitEntry>()), 0)
        let remainingSleep = try after.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(remainingSleep.count, 1)
        XCTAssertEqual(remainingSleep.first?.hours, 7.5)
    }

    /// 重複があっても、2回書いても対象は入れ替わらない。同じ値の2回目は更新時刻を変えない。
    func testRepeatedDuplicateWritesStayOnTheLatest() throws {
        guard let olderID = uuid("00000000-0000-0000-0000-00000000000A"),
              let newerID = uuid("00000000-0000-0000-0000-00000000000B") else {
            return
        }
        var tick = 0
        let origin = Date(timeIntervalSince1970: 1_800_000_000)
        let (store, context, _) = try makeStore(now: {
            let instant = Date(timeIntervalSince1970: origin.timeIntervalSince1970 + Double(tick))
            tick += 1
            return instant
        })
        let olderLine = MonthlyLogLine(
            id: olderID,
            dateKey: "2026-10-27",
            text: "古い行",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newerLine = MonthlyLogLine(
            id: newerID,
            dateKey: "2026-10-27",
            text: "新しい行",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let olderMood = MoodEntry(
            id: olderID,
            dateKey: "2026-10-28",
            level: 1,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newerMood = MoodEntry(
            id: newerID,
            dateKey: "2026-10-28",
            level: 2,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let olderSleep = SleepEntry(
            id: olderID,
            dateKey: "2026-10-29",
            hours: 6.0,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newerSleep = SleepEntry(
            id: newerID,
            dateKey: "2026-10-29",
            hours: 7.0,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        context.insert(olderLine)
        context.insert(newerLine)
        context.insert(olderMood)
        context.insert(newerMood)
        context.insert(olderSleep)
        context.insert(newerSleep)
        try context.save()

        try store.setLogLine(dateKey: "2026-10-27", text: "いち")
        XCTAssertEqual(tick, 1)
        try store.setLogLine(dateKey: "2026-10-27", text: "いち")
        XCTAssertEqual(tick, 1)
        try store.setLogLine(dateKey: "2026-10-27", text: "に")
        XCTAssertEqual(tick, 2)

        try store.setMood(dateKey: "2026-10-28", level: 4)
        XCTAssertEqual(tick, 3)
        try store.setMood(dateKey: "2026-10-28", level: 4)
        XCTAssertEqual(tick, 3)
        try store.setMood(dateKey: "2026-10-28", level: 5)
        XCTAssertEqual(tick, 4)

        try store.setSleep(dateKey: "2026-10-29", hours: 7.5)
        XCTAssertEqual(tick, 5)
        try store.setSleep(dateKey: "2026-10-29", hours: 7.5)
        XCTAssertEqual(tick, 5)
        try store.setSleep(dateKey: "2026-10-29", hours: 8.0)
        XCTAssertEqual(tick, 6)

        let lines = try context.fetch(FetchDescriptor<MonthlyLogLine>())
        XCTAssertEqual(lines.first { line in line.id == newerID }?.text, "に")
        XCTAssertEqual(lines.first { line in line.id == newerID }?.updatedAt, Date(timeIntervalSince1970: origin.timeIntervalSince1970 + 1))
        XCTAssertEqual(lines.first { line in line.id == olderID }?.text, "古い行")
        XCTAssertEqual(try store.logLine(dateKey: "2026-10-27")?.id, newerID)

        let moods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(moods.first { entry in entry.id == newerID }?.level, 5)
        XCTAssertEqual(moods.first { entry in entry.id == olderID }?.level, 1)
        XCTAssertEqual(try store.mood(dateKey: "2026-10-28")?.id, newerID)

        let sleeps = try context.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(sleeps.first { entry in entry.id == newerID }?.hours, 8.0)
        XCTAssertEqual(sleeps.first { entry in entry.id == olderID }?.hours, 6.0)
        XCTAssertEqual(try store.sleep(dateKey: "2026-10-29")?.id, newerID)
    }

    /// 今と同じ値なら、保存も更新時刻も変えない。月ページも新しくは作らない。
    func testSameValueDoesNotUpdateOrSave() throws {
        var tick = 0
        let origin = Date(timeIntervalSince1970: 1_810_000_000)
        let (store, context, _) = try makeStore(now: {
            let instant = Date(timeIntervalSince1970: origin.timeIntervalSince1970 + Double(tick))
            tick += 1
            return instant
        })
        let originalTime = Date(timeIntervalSince1970: 4_000)
        let line = MonthlyLogLine(
            dateKey: "2026-10-27",
            text: "そのまま",
            updatedAt: originalTime
        )
        context.insert(line)
        try context.save()

        try store.setLogLine(dateKey: "2026-10-27", text: "そのまま")
        XCTAssertEqual(tick, 0)
        XCTAssertEqual(line.updatedAt, originalTime)
        XCTAssertEqual(line.text, "そのまま")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0)

        try store.setMood(dateKey: "2026-10-28", level: 3)
        XCTAssertEqual(tick, 1)
        try store.setMood(dateKey: "2026-10-28", level: 3)
        XCTAssertEqual(tick, 1)
        let mood = try store.mood(dateKey: "2026-10-28")
        XCTAssertEqual(mood?.level, 3)
        XCTAssertEqual(mood?.updatedAt, origin)

        try store.setSleep(dateKey: "2026-10-29", hours: 8.0)
        XCTAssertEqual(tick, 2)
        try store.setSleep(dateKey: "2026-10-29", hours: 8.0)
        XCTAssertEqual(tick, 2)
        let sleep = try store.sleep(dateKey: "2026-10-29")
        XCTAssertEqual(sleep?.hours, 8.0)
        XCTAssertEqual(sleep?.updatedAt, Date(timeIntervalSince1970: origin.timeIntervalSince1970 + 1))
        try assertNoPage(in: context)
    }

    /// nil で消すと、その日の気分と睡眠の重複は全部消える。別の日は残る。
    func testNilClearsAllDuplicateMoodsAndSleep() throws {
        let (store, context, _) = try makeStore()
        let moods = [
            MoodEntry(dateKey: "2026-10-27", level: 1, updatedAt: Date(timeIntervalSince1970: 1_000)),
            MoodEntry(dateKey: "2026-10-27", level: 2, updatedAt: Date(timeIntervalSince1970: 2_000)),
            MoodEntry(dateKey: "2026-10-28", level: 5, updatedAt: Date(timeIntervalSince1970: 3_000)),
        ]
        let sleeps = [
            SleepEntry(dateKey: "2026-10-27", hours: 6.0, updatedAt: Date(timeIntervalSince1970: 1_000)),
            SleepEntry(dateKey: "2026-10-27", hours: 7.0, updatedAt: Date(timeIntervalSince1970: 2_000)),
            SleepEntry(dateKey: "2026-10-28", hours: 8.0, updatedAt: Date(timeIntervalSince1970: 3_000)),
        ]
        for entry in moods {
            context.insert(entry)
        }
        for entry in sleeps {
            context.insert(entry)
        }
        try context.save()

        try store.setMood(dateKey: "2026-10-27", level: nil)
        try store.setSleep(dateKey: "2026-10-27", hours: nil)

        let storedMoods = try context.fetch(FetchDescriptor<MoodEntry>())
        XCTAssertEqual(storedMoods.count, 1)
        XCTAssertEqual(storedMoods.first?.dateKey, "2026-10-28")
        XCTAssertEqual(storedMoods.first?.level, 5)
        XCTAssertNil(try store.mood(dateKey: "2026-10-27"))

        let storedSleeps = try context.fetch(FetchDescriptor<SleepEntry>())
        XCTAssertEqual(storedSleeps.count, 1)
        XCTAssertEqual(storedSleeps.first?.dateKey, "2026-10-28")
        XCTAssertEqual(storedSleeps.first?.hours, 8.0)
        XCTAssertNil(try store.sleep(dateKey: "2026-10-27"))
    }

    /// 全角空白だけの1行は消える。それだけを空の日に書いても、行は作られない。
    func testFullwidthSpaceDeletesLogLine() throws {
        let (store, context, _) = try makeStore()
        try store.setLogLine(dateKey: "2026-10-27", text: "ある")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 1)
        try store.setLogLine(dateKey: "2026-10-27", text: "　")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0)

        try store.setLogLine(dateKey: "2026-10-28", text: "　")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0)
        XCTAssertNil(try store.logLine(dateKey: "2026-10-28"))
    }

    /// 習慣の月と、記録する日の月が違うときはエラー。月が無い習慣は記録できる。
    func testToggleHabitRejectsMonthMismatch() throws {
        let (store, context, _) = try makeStore()
        let monthly = try store.findOrCreateMonthly(monthKey: "2026-10")
        let habit = Habit(name: "水", shortLabel: "水")
        context.insert(habit)
        habit.monthly = monthly
        try context.save()

        XCTAssertThrowsError(try store.toggleHabit(habitID: habit.id, dateKey: "2026-11-03")) { error in
            XCTAssertEqual(
                error as? JournalStoreError,
                .habitMonthMismatch(habitID: habit.id, dateKey: "2026-11-03")
            )
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 0)

        let turnedOn = try store.toggleHabit(habitID: habit.id, dateKey: "2026-10-27")
        XCTAssertTrue(turnedOn)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 1)

        XCTAssertThrowsError(try store.toggleHabit(habitID: habit.id, dateKey: "2026-11-03")) { error in
            XCTAssertEqual(
                error as? JournalStoreError,
                .habitMonthMismatch(habitID: habit.id, dateKey: "2026-11-03")
            )
        }
        let entries = try context.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.dateKey, "2026-10-27")

        let freeHabit = Habit(name: "自由", shortLabel: "自")
        context.insert(freeHabit)
        try context.save()
        let freeOn = try store.toggleHabit(habitID: freeHabit.id, dateKey: "2026-11-03")
        XCTAssertTrue(freeOn)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 2)
    }

    // MARK: - ヘルパー

    private func makeStore(
        now: (() -> Date)? = nil
    ) throws -> (store: JournalStore, context: ModelContext, container: ModelContainer) {
        let container = try StorageLocation.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let clock: () -> Date
        if let provided = now {
            clock = provided
        } else {
            let instant = fixedNow
            clock = { instant }
        }
        let store = JournalStore(context: context, now: clock)
        return (store, context, container)
    }

    private func uuid(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UUID? {
        guard let id = UUID(uuidString: text) else {
            XCTFail("UUID の文字列を読めませんでした", file: file, line: line)
            return nil
        }
        return id
    }

    private func assertNoPage(
        in context: ModelContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0, file: file, line: line)
    }

    private func assertNoStoredRecords(
        in context: ModelContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyLogLine>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MoodEntry>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitEntry>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTask>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskHistory>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyPage>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyPage>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Page>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PageLink>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 0, file: file, line: line)
    }
}
