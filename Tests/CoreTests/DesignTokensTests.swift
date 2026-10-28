import CoreGraphics
import XCTest
@testable import EasyJournal

/// 色の16進、余白、方眼のマスの大きさ。画面そのものは試さない。
final class DesignTokensTests: XCTestCase {
    func testNamedColorsMatchHexNumbers() {
        assertHex(
            DesignTokens.paperHex,
            stored: DesignTokens.paperRGB,
            red: 247,
            green: 244,
            blue: 236
        )
        assertHex(
            DesignTokens.inkHex,
            stored: DesignTokens.inkRGB,
            red: 47,
            green: 52,
            blue: 48
        )
        assertHex(
            DesignTokens.inkSubHex,
            stored: DesignTokens.inkSubRGB,
            red: 138,
            green: 143,
            blue: 136
        )
        assertHex(
            DesignTokens.accentHex,
            stored: DesignTokens.accentRGB,
            red: 94,
            green: 125,
            blue: 99
        )
        assertHex(
            DesignTokens.gridHex,
            stored: DesignTokens.gridRGB,
            red: 138,
            green: 154,
            blue: 140
        )
        XCTAssertEqual(DesignTokens.gridOpacity, 0.25)

        let withoutHash = DesignTokens.rgb(fromHex: "f7f4ec")
        XCTAssertEqual(withoutHash, DesignTokens.RGB(red: 247, green: 244, blue: 236))
    }

    func testInvalidHexReturnsNil() {
        let rejected = [
            "",
            "#",
            "#F7F4E",
            "#F7F4EC0",
            "#F7F4ECFF",
            "#FFF",
            "F7F4E",
            "#GGGGGG",
            "F7F4EG",
            "#F7F4EG",
            " #F7F4EC",
            "#F7F4EC ",
            "#F7F4 EC",
            "F7F4EC\n",
            "##F7F4EC",
            "0xF7F4EC",
        ]
        for text in rejected {
            XCTAssertNil(DesignTokens.rgb(fromHex: text), text)
        }
    }

    func testSpacingIsAscendingAndGridSizeIsTwenty() {
        let spaces = [
            DesignTokens.Spacing.xs,
            DesignTokens.Spacing.s,
            DesignTokens.Spacing.m,
            DesignTokens.Spacing.l,
            DesignTokens.Spacing.xl,
        ]
        XCTAssertEqual(spaces, [CGFloat(4), CGFloat(8), CGFloat(12), CGFloat(16), CGFloat(24)])
        for pair in zip(spaces, spaces.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1)
        }
        for space in spaces {
            XCTAssertEqual(space.truncatingRemainder(dividingBy: 4), CGFloat(0))
        }
        XCTAssertEqual(DesignTokens.gridSize, CGFloat(20))
    }

    private func assertHex(
        _ hex: String,
        stored: DesignTokens.RGB,
        red: Int,
        green: Int,
        blue: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = DesignTokens.RGB(red: red, green: green, blue: blue)
        XCTAssertEqual(DesignTokens.rgb(fromHex: hex), expected, hex, file: file, line: line)
        XCTAssertEqual(stored, expected, hex, file: file, line: line)
    }
}
