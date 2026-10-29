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
            "27日の文章が入力した文字になっていません"
        )
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
