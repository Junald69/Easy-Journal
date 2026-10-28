import SwiftUI

/// 色・余白・文字の名前つきの部品（デザイントークン）。
///
/// 数字は仮です。実機で見て、あとから変えます。
/// 暗い画面（ダークモード）用の色は、まだありません。紙の色は固定です。
enum DesignTokens {
    /// 赤・緑・青。それぞれ 0〜255。
    struct RGB: Equatable {
        let red: Int
        let green: Int
        let blue: Int
    }

    /// 16進の色（例: `#F7F4EC` または `F7F4EC`）を、赤・緑・青の数字にする。
    ///
    /// 受け付ける形は、6桁だけです。先頭の `#` はあってもなくてもよいです。大文字と小文字は同じです。
    /// 長さが違う、空白がある、ASCII の 0-9 と A-F 以外の文字があるときは nil です。
    /// `+` や `-` で始まる文字も nil です。全角の数字も nil です。クラッシュしません。
    /// 読めたときの赤・緑・青は、それぞれ 0〜255 です。
    /// `#RGB` のような短い書き方と、透明度つきの 8 桁は、使いません。
    static func rgb(fromHex text: String) -> RGB? {
        var digits = text
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        guard digits.count == 6 else { return nil }

        // 先に、1文字ずつ ASCII の 0-9 / a-f / A-F だけかを見る。
        // `Int(_:radix:)` は先頭の `+` と `-` も数字として読むので、使わない。
        // `Character.isHexDigit` は全角数字を通すことがあるので、使わない。
        var scalars: [Unicode.Scalar] = []
        for character in digits {
            let pieces = Array(character.unicodeScalars)
            guard pieces.count == 1, let scalar = pieces.first, asciiHexValue(scalar) != nil else {
                return nil
            }
            scalars.append(scalar)
        }
        guard scalars.count == 6 else { return nil }

        func channel(at offset: Int) -> Int? {
            guard offset >= 0, offset + 1 < scalars.count else { return nil }
            guard let high = asciiHexValue(scalars[offset]),
                  let low = asciiHexValue(scalars[offset + 1]) else {
                return nil
            }
            let number = high * 16 + low
            guard number >= 0, number <= 255 else { return nil }
            return number
        }

        guard let red = channel(at: 0),
              let green = channel(at: 2),
              let blue = channel(at: 4) else {
            return nil
        }
        return RGB(red: red, green: green, blue: blue)
    }

    /// ASCII の 0-9 / a-f / A-F だけを、0〜15 にする。それ以外は nil。
    private static func asciiHexValue(_ scalar: Unicode.Scalar) -> Int? {
        let code = scalar.value
        if code >= 0x30 && code <= 0x39 {
            return Int(code - 0x30)
        }
        if code >= 0x41 && code <= 0x46 {
            return Int(code - 0x41) + 10
        }
        if code >= 0x61 && code <= 0x66 {
            return Int(code - 0x61) + 10
        }
        return nil
    }

    /// 16進が読めなかったときだけ使う色。真っ黒。今の色の文字列は読めるので、通常は使いません。
    private static func resolvedRGB(fromHex text: String) -> RGB {
        rgb(fromHex: text) ?? RGB(red: 0, green: 0, blue: 0)
    }

    private static func color(from components: RGB, opacity: Double = 1) -> Color {
        Color(
            red: Double(components.red) / 255,
            green: Double(components.green) / 255,
            blue: Double(components.blue) / 255,
            opacity: opacity
        )
    }

    /// 紙の背景。仮の値 `#F7F4EC`。
    static let paperHex = "#F7F4EC"
    static let paperRGB = resolvedRGB(fromHex: paperHex)
    static let paper = color(from: paperRGB)

    /// 文字。仮の値 `#2F3430`。
    static let inkHex = "#2F3430"
    static let inkRGB = resolvedRGB(fromHex: inkHex)
    static let ink = color(from: inkRGB)

    /// 補助の文字・日付。仮の値 `#8A8F88`。
    static let inkSubHex = "#8A8F88"
    static let inkSubRGB = resolvedRGB(fromHex: inkSubHex)
    static let inkSub = color(from: inkSubRGB)

    /// ボタン・チェック。仮の値 `#5E7D63`。
    static let accentHex = "#5E7D63"
    static let accentRGB = resolvedRGB(fromHex: accentHex)
    static let accent = color(from: accentRGB)

    /// 方眼の線の色（透明度を掛ける前）。仮の値 `#8A9A8C`。
    static let gridHex = "#8A9A8C"
    static let gridRGB = resolvedRGB(fromHex: gridHex)
    /// 方眼の線の濃さ。仮。1 がそのまま、0 が透明。
    static let gridOpacity = 0.25
    static let grid = color(from: gridRGB, opacity: gridOpacity)

    /// 余白。全部 4 の倍数。単位は pt（点。画面上の長さ）。
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// 方眼の 1 マス。単位は pt。
    static let gridSize: CGFloat = 20

    /// 文字。固定の pt サイズは使わない。端末の「文字を大きく」に合わせる。
    enum Fonts {
        /// 本文。
        static let bodyText = Font.body
        /// 補助の文字。
        static let subText = Font.caption
        /// 見出し。セリフ体（文字の端に小さな飾りがある書体）。見た目は実機で未確認。
        static let heading = Font.system(.title3, design: .serif)
    }
}
