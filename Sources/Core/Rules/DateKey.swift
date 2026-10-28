import Foundation

/// 日付キー（`yyyy-MM-dd`）と月キー（`yyyy-MM`）のルール。
///
/// ある瞬間（`Date`）とキーの変換だけが、タイムゾーンに依存する。
/// キー同士の計算は、UTC 固定のグレゴリオ暦で行い、夏時間の日の長さの影響を受けない。
/// 24時間を足す計算（`addingTimeInterval` など）は使わない。
/// 「今日」は呼び出すたびに計算し、結果は保存しない。
enum DateKey {
    /// 曜日。数値は `Calendar` の weekday と同じ（日曜が 1）。
    enum Weekday: Int {
        case sunday = 1
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
    }

    /// グレゴリオ暦を作り、タイムゾーンを設定して返す。
    /// 端末の暦（仏暦・和暦など）は使わない。
    static func makeCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// ある瞬間を、渡した暦のタイムゾーンで `yyyy-MM-dd` にする。
    static func dayKey(from date: Date, calendar: Calendar) -> String {
        let gregorian = normalizedCalendar(calendar)
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return dayString(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// ある瞬間を、渡した暦のタイムゾーンで `yyyy-MM` にする。
    static func monthKey(from date: Date, calendar: Calendar) -> String {
        let gregorian = normalizedCalendar(calendar)
        let parts = gregorian.dateComponents([.year, .month], from: date)
        return monthString(year: parts.year ?? 0, month: parts.month ?? 0)
    }

    /// 「今日」の日付キー。`now` はそのときの時計。
    /// 結果は保存しない。日付が変わったあとは、呼び直せば新しい日になる。
    static func todayKey(now: Date, calendar: Calendar) -> String {
        dayKey(from: now, calendar: calendar)
    }

    /// 日付キーの日の始まりの瞬間。形式が不正、または存在しない日なら nil。
    /// 始まりの瞬間は、渡した暦の `startOfDay(for:)` で決める。
    static func startOfDay(for key: String, calendar: Calendar) -> Date? {
        let gregorian = normalizedCalendar(calendar)
        guard let parts = dayParts(key) else { return nil }
        var components = DateComponents()
        components.timeZone = gregorian.timeZone
        components.year = parts.year
        components.month = parts.month
        components.day = parts.day
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let date = gregorian.date(from: components) else { return nil }
        let back = gregorian.dateComponents([.year, .month, .day], from: date)
        guard back.year == parts.year, back.month == parts.month, back.day == parts.day else {
            return nil
        }
        return gregorian.startOfDay(for: date)
    }

    /// `yyyy-MM-dd` だけを許す。ゼロ埋めなし、空白、存在しない日は不可。
    static func isValidDayKey(_ s: String) -> Bool {
        dayParts(s) != nil
    }

    /// `yyyy-MM` だけを許す。ゼロ埋めなし、空白、月が 1〜12 の外は不可。
    static func isValidMonthKey(_ s: String) -> Bool {
        monthParts(s) != nil
    }

    /// 次の日の日付キー。不正なキーなら nil。
    static func nextDayKey(after key: String) -> String? {
        shiftedDayKey(byAdding: 1, to: key)
    }

    /// 前の日の日付キー。不正なキーなら nil。
    static func previousDayKey(before key: String) -> String? {
        shiftedDayKey(byAdding: -1, to: key)
    }

    /// その月の日数。不正な月キーなら nil。
    static func daysInMonth(monthKey key: String) -> Int? {
        guard let parts = monthParts(key), let calendar = gregorianUTC() else { return nil }
        guard let date = utcDate(year: parts.year, month: parts.month, day: 1, calendar: calendar) else {
            return nil
        }
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return nil }
        return range.count
    }

    /// その月の日付キーを、1日から順に返す。不正なら空配列。
    static func dayKeys(inMonth key: String) -> [String] {
        guard let parts = monthParts(key), let count = daysInMonth(monthKey: key) else {
            return []
        }
        return (1...count).map { day in
            dayString(year: parts.year, month: parts.month, day: day)
        }
    }

    /// 日付キーから月キーを取り出す。不正な日付キーなら nil。
    static func monthKey(ofDayKey key: String) -> String? {
        guard let parts = dayParts(key) else { return nil }
        return monthString(year: parts.year, month: parts.month)
    }

    /// 日付キーの曜日。不正な日付キーなら nil。
    static func weekday(ofDayKey key: String) -> Weekday? {
        guard let parts = dayParts(key), let calendar = gregorianUTC() else { return nil }
        guard let date = utcDate(year: parts.year, month: parts.month, day: parts.day, calendar: calendar) else {
            return nil
        }
        return Weekday(rawValue: calendar.component(.weekday, from: date))
    }

    /// 渡された暦が仏暦などでも、グレゴリオ暦に直す。タイムゾーンだけ引き継ぐ。
    private static func normalizedCalendar(_ calendar: Calendar) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian
    }

    // MARK: - キー同士の計算（タイムゾーンに依存させない）

    /// 年月日の計算専用。タイムゾーンは UTC、暦はグレゴリオ暦。
    private static func gregorianUTC() -> Calendar? {
        guard let timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "UTC") else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private static func shiftedDayKey(byAdding days: Int, to key: String) -> String? {
        guard let parts = dayParts(key), let calendar = gregorianUTC() else { return nil }
        guard let date = utcDate(year: parts.year, month: parts.month, day: parts.day, calendar: calendar) else {
            return nil
        }
        guard let shifted = calendar.date(
            byAdding: .day,
            value: days,
            to: date,
            wrappingComponents: false
        ) else {
            return nil
        }
        return self.dayKey(from: shifted, calendar: calendar)
    }

    /// グレゴリオ暦に実在する日だけを Date にする。存在しなければ nil。
    private static func utcDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let date = calendar.date(from: components) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == year, back.month == month, back.day == day else { return nil }
        return date
    }

    private static func dayParts(_ s: String) -> (year: Int, month: Int, day: Int)? {
        guard let (year, month, day) = splitDay(s), let calendar = gregorianUTC() else { return nil }
        guard utcDate(year: year, month: month, day: day, calendar: calendar) != nil else { return nil }
        return (year, month, day)
    }

    private static func monthParts(_ s: String) -> (year: Int, month: Int)? {
        guard let (year, month) = splitMonth(s), let calendar = gregorianUTC() else { return nil }
        guard utcDate(year: year, month: month, day: 1, calendar: calendar) != nil else { return nil }
        return (year, month)
    }

    /// 文字の並びだけを見る。実在するかは見ない。
    private static func splitDay(_ s: String) -> (year: Int, month: Int, day: Int)? {
        let chars = Array(s)
        guard chars.count == 10, chars[4] == "-", chars[7] == "-" else { return nil }
        guard let year = digits(chars[0..<4]),
              let month = digits(chars[5..<7]),
              let day = digits(chars[8..<10]) else {
            return nil
        }
        return (year, month, day)
    }

    /// 文字の並びだけを見る。実在するかは見ない。
    private static func splitMonth(_ s: String) -> (year: Int, month: Int)? {
        let chars = Array(s)
        guard chars.count == 7, chars[4] == "-" else { return nil }
        guard let year = digits(chars[0..<4]), let month = digits(chars[5..<7]) else { return nil }
        return (year, month)
    }

    /// ASCII の数字だけを整数にする。全角数字や空白は不可。
    private static func digits(_ chars: ArraySlice<Character>) -> Int? {
        guard !chars.isEmpty, chars.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
        return Int(String(chars))
    }

    /// 数字の並びが地域設定で変わらないよう、固定の地域で `String(format:)` する。
    /// `%d` は 32bit 整数向けなので、`Int32` に収まるときだけ使う。収まらなければゼロ埋めする。
    private static let numberLocale = Locale(identifier: "en_US_POSIX")

    private static func dayString(year: Int, month: Int, day: Int) -> String {
        if let year = Int32(exactly: year),
           let month = Int32(exactly: month),
           let day = Int32(exactly: day) {
            return String(format: "%04d-%02d-%02d", locale: numberLocale, year, month, day)
        }
        return "\(zeroFilled(year, width: 4))-\(zeroFilled(month, width: 2))-\(zeroFilled(day, width: 2))"
    }

    private static func monthString(year: Int, month: Int) -> String {
        if let year = Int32(exactly: year),
           let month = Int32(exactly: month) {
            return String(format: "%04d-%02d", locale: numberLocale, year, month)
        }
        return "\(zeroFilled(year, width: 4))-\(zeroFilled(month, width: 2))"
    }

    private static func zeroFilled(_ value: Int, width: Int) -> String {
        let text = String(value)
        guard text.count < width else { return text }
        return String(repeating: "0", count: width - text.count) + text
    }
}
