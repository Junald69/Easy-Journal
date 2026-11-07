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

    /// タスクを3つ足して □ ◧ ■ を並べ、削除の確認をキャンセルと消すで見る。
    ///
    /// アラートとボタンは firstMatch。押す前に isHittable を待つ。
    /// キーボードの rightArrow は使わない。確定は「追加」ボタン。
    func testMonthlyTaskScreenshotAndDelete() {
        let app = launchMonthly(extraArguments: [], includeSampleData: false)
        waitForMonthlyLog(app)

        addTask("Cards", in: app)
        addTask("Tidy", in: app)
        cycleTask(title: "Tidy", from: "未完", to: "一部", in: app)
        addTask("Insurance", in: app)
        cycleTask(title: "Insurance", from: "未完", to: "一部", in: app)
        cycleTask(title: "Insurance", from: "一部", to: "完了", in: app)

        let open = taskButton("未完 Cards", in: app)
        let partial = taskButton("一部 Tidy", in: app)
        let done = taskButton("完了 Insurance", in: app)
        XCTAssertTrue(open.waitForExistence(timeout: 5), "未完 Cards がありません")
        XCTAssertTrue(partial.waitForExistence(timeout: 5), "一部 Tidy がありません")
        XCTAssertTrue(done.waitForExistence(timeout: 5), "完了 Insurance がありません")
        reveal(done, in: app)
        waitUntilHittable(done)
        attachScreenshot(app, name: "06-monthly-task")

        longPressTitle("Insurance", in: app)
        tapDeleteMenu(in: app)
        tapAlertButton("キャンセル", in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 5), "キャンセル後にタスクが消えました")
        XCTAssertTrue(open.exists, "キャンセル後に Cards がありません")
        XCTAssertTrue(partial.exists, "キャンセル後に Tidy がありません")

        longPressTitle("Insurance", in: app)
        tapDeleteMenu(in: app)
        tapAlertButton("消す", in: app)
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: done)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
        XCTAssertTrue(open.waitForExistence(timeout: 5), "消したあとに Cards がありません")
        XCTAssertTrue(partial.waitForExistence(timeout: 5), "消したあとに Tidy がありません")
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

    private func launchMonthly(
        extraArguments: [String] = [],
        includeSampleData: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-inMemoryStore",
            "-openPage",
            "monthly:2026-10",
            "-todayKey",
            "2026-10-27",
        ]
        if includeSampleData {
            arguments.insert("-sampleData", at: 0)
        }
        app.launchArguments = arguments + extraArguments
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

    /// 上の方を見せる。画面の真ん中から下へ滑らせる。
    /// 何回で一番上に着くかは、ここでは確かめられない。
    private func scrollTowardTop(_ app: XCUIApplication) {
        var attempt = 0
        while attempt < 6 {
            app.swipeDown()
            attempt += 1
        }
    }

    private func addTask(_ title: String, in app: XCUIApplication) {
        let addButton = app.descendants(matching: .any)["monthlyTaskAddButton"].firstMatch
        reveal(addButton, in: app)
        tapWhenHittable(addButton)
        let field = app.textFields["monthlyTaskTitleField"].firstMatch
        tapWhenHittable(field)
        field.typeText(title)
        let confirm = app.descendants(matching: .any)["monthlyTaskConfirmButton"].firstMatch
        reveal(confirm, in: app)
        if confirm.isHittable {
            tapWhenHittable(confirm)
        } else if field.isHittable {
            field.typeText("\n")
        } else {
            tapWhenHittable(confirm)
        }
        let created = taskButton("未完 " + title, in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 5), "追加後の未完が見つかりません: " + title)
    }

    private func cycleTask(title: String, from: String, to: String, in app: XCUIApplication) {
        let current = taskButton(from + " " + title, in: app)
        reveal(current, in: app)
        tapWhenHittable(current)
        let updated = taskButton(to + " " + title, in: app)
        XCTAssertTrue(updated.waitForExistence(timeout: 5), to + " " + title)
    }

    private func taskButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func longPressTitle(_ title: String, in app: XCUIApplication) {
        let identified = app.descendants(matching: .any)["monthlyTaskLabel-" + title].firstMatch
        let target: XCUIElement
        if identified.waitForExistence(timeout: 2) {
            target = identified
        } else {
            target = app.staticTexts[title].firstMatch
        }
        reveal(target, in: app)
        if waitUntilHittable(target) {
            target.press(forDuration: 1.2)
        }
    }

    private func tapDeleteMenu(in app: XCUIApplication) {
        let identified = app.descendants(matching: .any)["monthlyTaskDeleteAction"].firstMatch
        if identified.waitForExistence(timeout: 3) {
            tapWhenHittable(identified)
            return
        }
        let labeled = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "削除")
        ).firstMatch
        XCTAssertTrue(labeled.waitForExistence(timeout: 3), "削除のメニューがありません")
        tapWhenHittable(labeled)
    }

    private func tapAlertButton(_ title: String, in app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "確認のアラートがありません")
        let button = alert.buttons[title].firstMatch
        tapWhenHittable(button)
    }

    /// 画面の外なら、上へ滑らせて見えるようにする。見えているときは滑らせない。
    ///
    /// すぐには滑らせない。アニメーションで押せるようになるのを、先に少し待つ。
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "要素がありません")
        var attempt = 0
        while element.isHittable == false && attempt < attempts {
            let ready = NSPredicate(format: "isHittable == true")
            let expectation = XCTNSPredicateExpectation(predicate: ready, object: element)
            if XCTWaiter().wait(for: [expectation], timeout: 1) == .completed {
                return
            }
            app.swipeUp()
            attempt += 1
        }
    }

    /// 押せるようになるまで待ってからタップする。待てなければ押さない。
    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 8) {
        let ready = waitUntilHittable(element, timeout: timeout)
        if ready == false {
            return
        }
        element.tap()
    }

    @discardableResult
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "要素がありません")
        let ready = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: ready, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed)
        return result == .completed
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
