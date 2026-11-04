import XCTest

/// 月の左ページを撮る。機種は CI が選んだ iPhone 1台だけ。
final class ScreenshotTests: XCTestCase {
    /// 開いた直後（今日の 27 日）と、上までスクロールしたあと（1 日）。
    func testMonthlyLogScreenshots() {
        let app = launchMonthly()
        waitForMonthlyLog(app)
        attachScreenshot(app, name: "01-monthly-today")

        scrollTowardTop(app)
        let firstRow = app.descendants(matching: .any)["monthlyLogRow-2026-10-01"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "1日の行がありません")
        attachScreenshot(app, name: "02-monthly-top")
    }

    /// 27日の文章を編集し、26日へ移したあと、27日に文字が残っている。
    func testMonthlyLogEditKeepsTextOnAnotherRow() {
        let editedText = "T112edit"
        let app = launchMonthly()
        waitForMonthlyLog(app)

        let day27 = app.descendants(matching: .any)["monthlyLogText-2026-10-27"]
        XCTAssertTrue(day27.waitForExistence(timeout: 10), "27日の文章がありません")
        day27.tap()

        let field = app.descendants(matching: .textField)["monthlyLogText-2026-10-27"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "27日の編集欄がありません")
        field.tap()
        field.typeText(editedText)

        tapMonthlyText(app, dateKey: "2026-10-26")

        let field26 = app.descendants(matching: .textField)["monthlyLogText-2026-10-26"]
        XCTAssertTrue(field26.waitForExistence(timeout: 10), "26日の編集欄がありません")
        waitUntilTextShows(app, dateKey: "2026-10-27", text: editedText)
        let stillEditing27 = app.descendants(matching: .textField)["monthlyLogText-2026-10-27"]
        XCTAssertFalse(stillEditing27.exists, "27日が編集欄のままです")
        attachScreenshot(app, name: "04-monthly-edited")
    }

    /// 文章がある行を空にして確定すると確認が出る。
    /// キャンセルでは元の文字が残り、消すとその行が空になる。
    func testMonthlyLogDeleteConfirmationRestoresOrClearsLine() {
        let dateKey = "2026-10-24"
        let original = "資料"
        let app = launchMonthly()
        waitForMonthlyLog(app)

        let field = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: field, knownText: original, app: app)
        field.typeText(XCUIKeyboardKey.return.rawValue)

        let alert = app.alerts["この行を消しますか？"].firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "削除の確認が出ません")
        let cancelButton = alert.buttons["キャンセル"].firstMatch
        let deleteButton = alert.buttons["消す"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "キャンセルがありません")
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "消すがありません")
        attachScreenshot(app, name: "05-monthly-delete-confirm")
        waitUntilHittable(cancelButton, message: "キャンセルを押せません")
        cancelButton.tap()

        waitUntilGone(alert, message: "確認が閉じません")
        waitUntilTextShows(app, dateKey: dateKey, text: original)
        assertMonthlyFieldClosed(app, dateKey: dateKey)

        let fieldAgain = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: fieldAgain, knownText: original, app: app)
        fieldAgain.typeText(XCUIKeyboardKey.return.rawValue)

        let alertAgain = app.alerts["この行を消しますか？"].firstMatch
        XCTAssertTrue(alertAgain.waitForExistence(timeout: 10), "もう一度、削除の確認が出ません")
        let cancelAgain = alertAgain.buttons["キャンセル"].firstMatch
        let confirmButton = alertAgain.buttons["消す"].firstMatch
        XCTAssertTrue(cancelAgain.waitForExistence(timeout: 5), "キャンセルがありません")
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "消すがありません")
        waitUntilHittable(confirmButton, message: "消すを押せません")
        confirmButton.tap()

        waitUntilGone(alertAgain, message: "確認が閉じません")
        waitUntilTextHides(app, dateKey: dateKey, text: original)
        assertMonthlyFieldClosed(app, dateKey: dateKey)
    }

    /// 文字を大きくしたときの月の画面。
    func testMonthlyLogLargeTextScreenshot() {
        let app = launchMonthly(extraArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL",
        ])
        waitForMonthlyLog(app)
        attachScreenshot(app, name: "03-monthly-large-text")
    }

    private func launchMonthly(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-sampleData",
            "-inMemoryStore",
            "-openPage",
            "monthly:2026-10",
            "-todayKey",
            "2026-10-27",
        ] + extraArguments
        app.launch()
        return app
    }

    private func waitForMonthlyLog(_ app: XCUIApplication) {
        let screen = app.descendants(matching: .any)["monthlyLogScreen"]
        XCTAssertTrue(
            screen.waitForExistence(timeout: 10),
            "月の画面が表示されませんでした"
        )
        let title = app.descendants(matching: .any)["monthlyTitle"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 10),
            "月のタイトルが表示されませんでした"
        )
        let todayRow = app.descendants(matching: .any)["monthlyLogRow-2026-10-27"]
        XCTAssertTrue(
            todayRow.waitForExistence(timeout: 10),
            "27日の行がありません"
        )
    }

    /// 文章の部分を押す。隠れていたら、見えるまで少しずらす。固定の待ちは使わない。
    private func tapMonthlyText(_ app: XCUIApplication, dateKey: String) {
        let element = app.descendants(matching: .any)["monthlyLogText-" + dateKey]
        XCTAssertTrue(
            element.waitForExistence(timeout: 10),
            dateKey + " の文章がありません"
        )
        var attempt = 0
        while element.isHittable == false && attempt < 3 {
            app.swipeDown()
            attempt += 1
        }
        XCTAssertTrue(element.isHittable, dateKey + " の文章を押せません")
        element.tap()
    }

    /// 読み上げの文か、欄の値に、入力した文字が出るまで待つ。
    private func waitUntilTextShows(_ app: XCUIApplication, dateKey: String, text: String) {
        let element = app.descendants(matching: .any)["monthlyLogText-" + dateKey]
        let showed = NSPredicate(block: { evaluated, _ in
            guard let rowText = evaluated as? XCUIElement else {
                return false
            }
            if rowText.label.contains(text) {
                return true
            }
            if let value = rowText.value as? String, value.contains(text) {
                return true
            }
            return false
        })
        let expectation = XCTNSPredicateExpectation(predicate: showed, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 10),
            .completed,
            dateKey + " の文章が、期待した文字になっていません"
        )
    }

    /// 文章の部分を開き、編集欄を返す。隠れていたら、見えるまで少しずらす。
    private func openMonthlyField(_ app: XCUIApplication, dateKey: String) -> XCUIElement {
        tapMonthlyText(app, dateKey: dateKey)
        let field = app.descendants(matching: .textField)["monthlyLogText-" + dateKey]
        XCTAssertTrue(
            field.waitForExistence(timeout: 10),
            dateKey + " の編集欄がありません"
        )
        let hittable = NSPredicate(block: { evaluated, _ in
            guard let editor = evaluated as? XCUIElement else {
                return false
            }
            return editor.isHittable
        })
        let ready = XCTNSPredicateExpectation(predicate: hittable, object: field)
        XCTAssertEqual(
            XCTWaiter().wait(for: [ready], timeout: 5),
            .completed,
            dateKey + " の編集欄を押せません"
        )
        field.tap()
        return field
    }

    /// 編集欄の文字を、末尾から delete キーだけで消す。空になったら終わる。
    ///
    /// ソフトウェアキーボードに矢印キーはない。右端をタップしてカーソルを末尾に置く。
    /// 残ったときは、編集メニューの「すべてを選択」から1回だけ消す。
    private func deleteAllCharacters(
        in field: XCUIElement,
        knownText: String,
        app: XCUIApplication
    ) {
        var attempt = 0
        while attempt < 4 {
            let shown = field.value as? String ?? ""
            if shown.isEmpty && attempt > 0 {
                return
            }
            var deleteCount = shown.count
            if deleteCount < knownText.count {
                deleteCount = knownText.count
            }
            deleteCount += 2
            let endOfField = field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5))
            endOfField.tap()
            let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount)
            field.typeText(deletes)
            attempt += 1
        }
        let afterDeletes = field.value as? String ?? ""
        if afterDeletes.isEmpty == false {
            selectAllThenDelete(in: field, app: app)
        }
        let leftover = field.value as? String ?? ""
        XCTAssertEqual(leftover, "", "文章を全部消せませんでした")
    }

    /// 長押しの編集メニューで全文を選んでから、delete を1回送る。
    ///
    /// 「Select All」も「すべてを選択」も無いときは、何もしない。
    private func selectAllThenDelete(in field: XCUIElement, app: XCUIApplication) {
        field.press(forDuration: 1.0)
        let english = app.menuItems["Select All"]
        let japanese = app.menuItems["すべてを選択"]
        let appeared = NSPredicate(block: { _, _ in
            if english.exists {
                return true
            }
            if japanese.exists {
                return true
            }
            return false
        })
        let ready = XCTNSPredicateExpectation(predicate: appeared, object: app)
        let result = XCTWaiter().wait(for: [ready], timeout: 2)
        if result != .completed {
            return
        }
        if english.exists {
            english.tap()
        } else if japanese.exists {
            japanese.tap()
        } else {
            return
        }
        field.typeText(XCUIKeyboardKey.delete.rawValue)
    }

    /// 編集を閉じたあと、その日の文章に指定の文字が残っていないこと。
    private func waitUntilTextHides(_ app: XCUIApplication, dateKey: String, text: String) {
        let element = app.descendants(matching: .any)["monthlyLogText-" + dateKey]
        let hidden = NSPredicate(block: { evaluated, _ in
            guard let rowText = evaluated as? XCUIElement else {
                return false
            }
            if rowText.exists == false {
                return false
            }
            if rowText.label.contains(text) {
                return false
            }
            if let value = rowText.value as? String, value.contains(text) {
                return false
            }
            return true
        })
        let expectation = XCTNSPredicateExpectation(predicate: hidden, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 10),
            .completed,
            dateKey + " の文章が残っています"
        )
    }

    /// ボタンが押せるまで待つ。同じ見た目の要素が複数あっても、渡した1つだけを見る。
    private func waitUntilHittable(_ element: XCUIElement, message: String) {
        let hittable = NSPredicate(block: { evaluated, _ in
            guard let button = evaluated as? XCUIElement else {
                return false
            }
            return button.isHittable
        })
        let ready = XCTNSPredicateExpectation(predicate: hittable, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [ready], timeout: 5),
            .completed,
            message
        )
    }

    /// 確認のアラートが閉じるまで待つ。
    private func waitUntilGone(_ element: XCUIElement, message: String) {
        let gone = NSPredicate(block: { evaluated, _ in
            guard let alert = evaluated as? XCUIElement else {
                return false
            }
            return alert.exists == false
        })
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 10),
            .completed,
            message
        )
    }

    /// その日が編集欄のままではないこと。
    private func assertMonthlyFieldClosed(_ app: XCUIApplication, dateKey: String) {
        let field = app.descendants(matching: .textField)["monthlyLogText-" + dateKey]
        XCTAssertFalse(field.exists, dateKey + " が編集欄のままです")
    }

    /// 上の方を見せる。画面の真ん中から下へ滑らせる。
    /// 何回で一番上に着くかは、ここでは確かめられない。
    private func scrollTowardTop(_ app: XCUIApplication) {
        var attempt = 0
        while attempt < 6 {
            app.swipeDown()
            attempt += 1
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
