import XCTest
@testable import EasyJournal

/// 文章がある行を空にする前に、確認が要るか。保存しない。画面を使わない。
final class MonthlyLogEditRuleTests: XCTestCase {
    /// 元の文字と下書きを、前後の空白と改行を除いて比べる。
    func testNeedsDeleteConfirmation() {
        struct Row {
            let name: String
            let original: String?
            let draft: String
            let needsConfirmation: Bool
        }

        let rows = [
            Row(
                name: "元ありから空",
                original: "会議",
                draft: "",
                needsConfirmation: true
            ),
            Row(
                name: "元ありから空白と改行だけ",
                original: "会議",
                draft: " \n\t ",
                needsConfirmation: true
            ),
            Row(
                name: "元ありから別の文字",
                original: "会議",
                draft: "別の予定",
                needsConfirmation: false
            ),
            Row(
                name: "元なしから空",
                original: nil,
                draft: "",
                needsConfirmation: false
            ),
            Row(
                name: "元が空から空",
                original: "",
                draft: "",
                needsConfirmation: false
            ),
            Row(
                name: "元が空白だけから空",
                original: " \n",
                draft: "",
                needsConfirmation: false
            ),
        ]

        for row in rows {
            let needs = MonthlyLogEditRule.needsDeleteConfirmation(
                original: row.original,
                draft: row.draft
            )
            XCTAssertEqual(needs, row.needsConfirmation, row.name)
        }
    }
}
