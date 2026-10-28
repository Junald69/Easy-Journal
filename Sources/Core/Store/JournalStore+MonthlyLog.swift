import Foundation
import SwiftData

/// 月の左ページを読むための結果。書く内容は持たない。
struct MonthlyLogContent: Equatable {
    /// その月に属する日の、選ばれた1行。無い日は入れない。
    var textByDateKey: [String: String]
    /// 中身のある Daily がある日付キー。その月のものだけ。
    var dailyDateKeys: Set<String>
}

extension JournalStore {
    /// その月の1行と、Daily がある日を返す。読むだけ。何も作らない・保存しない。
    ///
    /// 月ページが無いときは、空を返す。目次カードも行も作らない。
    /// 1行は、保存してある行を1回取り、その月の日付だけを残す。
    /// 同じ日が複数あるときは、`logLine` と同じ。更新時刻が新しい方。同時刻なら id の文字順が大きい方。
    /// 月に属さない日付キーと、不正な日付キーは無視する。
    /// Daily は、目次カードを1回取り、種類が daily のものだけを Swift で残す。そのあと日付と中身で絞る。
    func monthlyLogContent(monthKey: String) throws -> MonthlyLogContent {
        if try findMonthly(monthKey: monthKey) == nil {
            return MonthlyLogContent(textByDateKey: [:], dailyDateKeys: [])
        }
        let storedLines = try storedModels(MonthlyLogLine.self)
        let textByDateKey = texts(in: storedLines, monthKey: monthKey)
        let markedDateKeys = try dailyDateKeys(inMonth: monthKey)
        return MonthlyLogContent(
            textByDateKey: textByDateKey,
            dailyDateKeys: markedDateKeys
        )
    }

    /// 保存してある行から、その月の日だけを残し、同じ日は1件に選ぶ。
    private func texts(in stored: [MonthlyLogLine], monthKey: String) -> [String: String] {
        var grouped: [String: [MonthlyLogLine]] = [:]
        for line in stored {
            let lineDateKey = line.dateKey
            guard DateKey.isValidDayKey(lineDateKey) else {
                continue
            }
            guard DateKey.monthKey(ofDayKey: lineDateKey) == monthKey else {
                continue
            }
            var sameDay = grouped[lineDateKey] ?? []
            sameDay.append(line)
            grouped[lineDateKey] = sameDay
        }
        var texts: [String: String] = [:]
        for (lineDateKey, lines) in grouped {
            guard let chosen = preferredLine(lines) else {
                continue
            }
            texts[lineDateKey] = chosen.text
        }
        return texts
    }

    /// 更新時刻が一番新しい行。同時刻なら id の文字順が大きい方。空なら nil。
    ///
    /// `logLine` の選び方と同じ。比較の向きも同じ（古い方・id が小さい方を先にする）。
    private func preferredLine(_ lines: [MonthlyLogLine]) -> MonthlyLogLine? {
        lines.max { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt < rhs.updatedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// 中身のある Daily の日付キー。その月だけ。目次カードの取得は1回。
    private func dailyDateKeys(inMonth monthKey: String) throws -> Set<String> {
        let storedPages = try storedModels(Page.self)
        var marked: Set<String> = []
        for page in storedPages {
            guard page.kindRaw == PageKind.daily.rawValue else {
                continue
            }
            guard let lineDateKey = page.dateKey else {
                continue
            }
            guard DateKey.isValidDayKey(lineDateKey) else {
                continue
            }
            guard DateKey.monthKey(ofDayKey: lineDateKey) == monthKey else {
                continue
            }
            guard page.daily != nil else {
                continue
            }
            marked.insert(lineDateKey)
        }
        return marked
    }
}
