import XCTest
@testable import EasyJournal

/// 編集中の元の文字を、読み直しの失敗から守る。保存しない。画面を使わない。
final class MonthlyLogEditSessionTests: XCTestCase {
    /// 表示を空にしても、開始時の文字で確認し、キャンセルではその文字に戻す。
    ///
    /// 保存に成功したあとは、保存した下書きが元になる。
    func testKeepsOriginalWhenDisplayIsEmpty() {
        struct Row {
            let name: String
            let original: String?
            let savedText: String?
            let draft: String
            let needsConfirmation: Bool
            let restored: String
        }

        let rows = [
            Row(
                name: "元「資料」で開始し、表示が空でも下書き空は確認が要る",
                original: "資料",
                savedText: nil,
                draft: "",
                needsConfirmation: true,
                restored: "資料"
            ),
            Row(
                name: "「資料2」の保存成功のあと、下書き空は確認が要り、キャンセルは「資料2」",
                original: "資料",
                savedText: "資料2",
                draft: "",
                needsConfirmation: true,
                restored: "資料2"
            ),
            Row(
                name: "元が空の行は確認不要",
                original: "",
                savedText: nil,
                draft: "",
                needsConfirmation: false,
                restored: ""
            ),
            Row(
                name: "元が無い行は確認不要",
                original: nil,
                savedText: nil,
                draft: "",
                needsConfirmation: false,
                restored: ""
            ),
        ]

        for row in rows {
            var displayed: [String: String] = [:]
            if let original = row.original {
                displayed["2026-10-24"] = original
            }
            var session = MonthlyLogEditSession()
            session.begin(original: displayed["2026-10-24"])
            if let savedText = row.savedText {
                session.didSave(text: savedText)
            }
            // 読み直しの失敗。表示の文字は空。セッションはこの辞書を見ない。
            displayed = [:]
            XCTAssertNil(displayed["2026-10-24"], row.name)
            XCTAssertEqual(
                session.needsDeleteConfirmation(draft: row.draft),
                row.needsConfirmation,
                row.name
            )
            XCTAssertEqual(session.restoreText, row.restored, row.name)
        }

        var closed = MonthlyLogEditSession()
        closed.begin(original: "資料")
        closed.clear()
        XCTAssertFalse(closed.needsDeleteConfirmation(draft: ""))
        XCTAssertEqual(closed.restoreText, "")
    }
}
