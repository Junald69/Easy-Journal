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

    /// タスクを3つ足して □ ◧ ■ を並べ、削除の確認をキャンセルと消すで見る。
    ///
    /// アラートとボタンは firstMatch。押す前に isHittable を待つ。
    /// キーボードの右矢印は使わない。確定は「追加」ボタン。
    func testMonthlyTaskScreenshotAndDelete() {
        let app = launchMonthly(includeSampleData: false)
        waitForMonthlyLog(app)

        addMonthlyTask("Cards", in: app)
        addMonthlyTask("Tidy", in: app)
        cycleMonthlyTask(title: "Tidy", from: "未完", to: "一部", in: app)
        addMonthlyTask("Insurance", in: app)
        cycleMonthlyTask(title: "Insurance", from: "未完", to: "一部", in: app)
        cycleMonthlyTask(title: "Insurance", from: "一部", to: "完了", in: app)

        let open = monthlyTaskButton("未完 Cards", in: app)
        let partial = monthlyTaskButton("一部 Tidy", in: app)
        let done = monthlyTaskButton("完了 Insurance", in: app)
        XCTAssertTrue(open.waitForExistence(timeout: 5), "未完 Cards がありません")
        XCTAssertTrue(partial.waitForExistence(timeout: 5), "一部 Tidy がありません")
        XCTAssertTrue(done.waitForExistence(timeout: 5), "完了 Insurance がありません")
        revealMonthlyTask(done, in: app)
        waitUntilHittable(done, message: "完了 Insurance を押せません")
        attachScreenshot(app, name: "06-monthly-task")

        longPressMonthlyTask("Insurance", in: app)
        tapMonthlyTaskDeleteMenu(in: app)
        tapMonthlyTaskAlertButton("キャンセル", in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 5), "キャンセル後にタスクが消えました")
        XCTAssertTrue(open.exists, "キャンセル後に Cards がありません")
        XCTAssertTrue(partial.exists, "キャンセル後に Tidy がありません")

        longPressMonthlyTask("Insurance", in: app)
        tapMonthlyTaskDeleteMenu(in: app)
        tapMonthlyTaskAlertButton("消す", in: app)
        waitUntilGone(done, message: "消したタスクが残っています")
        XCTAssertTrue(open.waitForExistence(timeout: 5), "消したあとに Cards がありません")
        XCTAssertTrue(partial.waitForExistence(timeout: 5), "消したあとに Tidy がありません")
    }

    /// タスクが多くても、最後の記号はタスク欄の中を滑らせれば押せる。ログは押し出さない。
    func testManyMonthlyTasksLastSymbolStaysReachable() {
        let app = launchMonthly(includeSampleData: false)
        waitForMonthlyLog(app)
        let lastIndex = 7
        var index = 0
        while index <= lastIndex {
            addMonthlyTask("t" + String(index), in: app)
            index += 1
        }

        let last = revealLastMonthlyTask("未完 t" + String(lastIndex), in: app)
        waitUntilHittable(last, message: "最後のタスクを押せません")
        last.tap()
        let advanced = monthlyTaskButton("一部 t" + String(lastIndex), in: app)
        XCTAssertTrue(advanced.waitForExistence(timeout: 5), "最後のタスクの状態が変わりません")

        let logScroll = app.scrollViews.containing(
            .any,
            identifier: "monthlyLogRow-2026-10-27"
        ).firstMatch
        XCTAssertTrue(logScroll.waitForExistence(timeout: 5), "ログのスクロールがありません")
        XCTAssertGreaterThan(logScroll.frame.height, 80, "ログの行を滑らせる余地がありません")
    }

    /// 文章がある行を空にしたあと、タスクの記号を押す。
    ///
    /// 行を消す確認が出て、タスクの状態は変わらない。キャンセルで元の文章が戻る。
    /// アラートとボタンは firstMatch。押す前に isHittable を待つ。
    func testClearingLogLineThenTappingTaskSymbolKeepsTask() {
        let dateKey = "2026-10-24"
        let original = "資料"
        let taskLabel = "未完 今月のねらい"
        let app = launchMonthly()
        waitForMonthlyLog(app)

        let field = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: field, knownText: original, app: app)

        // 記号はページの下にあり、キーボードより上に出る。ログは滑らせない。
        // 滑らせるとキーボードが閉じて、空の下書きが確定してしまう。
        let symbol = waitForMonthlyTaskSymbolAboveKeyboard(taskLabel, in: app)
        waitUntilHittable(symbol, message: "タスクの記号を押せません")
        symbol.tap()

        let alert = app.alerts["この行を消しますか？"].firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "行を消す確認が出ません")
        let unchanged = monthlyTaskButton(taskLabel, in: app)
        XCTAssertTrue(unchanged.waitForExistence(timeout: 5), "タスクの状態が変わりました")
        let advanced = monthlyTaskButton("一部 今月のねらい", in: app)
        XCTAssertFalse(advanced.exists, "記号を押してタスクが進みました")

        let cancel = alert.buttons["キャンセル"].firstMatch
        waitUntilHittable(cancel, message: "キャンセルを押せません")
        cancel.tap()

        waitUntilGone(alert, message: "確認が閉じません")
        waitUntilTextShows(app, dateKey: dateKey, text: original)
        XCTAssertTrue(
            monthlyTaskButton(taskLabel, in: app).waitForExistence(timeout: 5),
            "キャンセル後にタスクの状態が変わりました"
        )
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

    private func addMonthlyTask(_ title: String, in app: XCUIApplication) {
        let addButton = app.descendants(matching: .any)["monthlyTaskAddButton"].firstMatch
        revealMonthlyTask(addButton, in: app)
        waitUntilHittable(addButton, message: "タスクの追加を押せません")
        addButton.tap()
        let field = app.textFields["monthlyTaskTitleField"].firstMatch
        waitUntilHittable(field, message: "タスクの名前欄を押せません")
        field.tap()
        field.typeText(title)
        let confirm = app.descendants(matching: .any)["monthlyTaskConfirmButton"].firstMatch
        revealMonthlyTask(confirm, in: app)
        if confirm.isHittable {
            waitUntilHittable(confirm, message: "タスクの追加の確定を押せません")
            confirm.tap()
        } else if field.isHittable {
            field.typeText("\n")
        } else {
            waitUntilHittable(confirm, message: "タスクの追加の確定を押せません")
            confirm.tap()
        }
        let created = monthlyTaskButton("未完 " + title, in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 5), "追加後の未完が見つかりません: " + title)
    }

    private func cycleMonthlyTask(title: String, from: String, to: String, in app: XCUIApplication) {
        let current = monthlyTaskButton(from + " " + title, in: app)
        revealMonthlyTask(current, in: app)
        waitUntilHittable(current, message: from + " " + title + " を押せません")
        current.tap()
        let updated = monthlyTaskButton(to + " " + title, in: app)
        XCTAssertTrue(updated.waitForExistence(timeout: 5), to + " " + title)
    }

    private func monthlyTaskButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func longPressMonthlyTask(_ title: String, in app: XCUIApplication) {
        let identified = app.descendants(matching: .any)["monthlyTaskLabel-" + title].firstMatch
        let target: XCUIElement
        if identified.waitForExistence(timeout: 2) {
            target = identified
        } else {
            target = app.staticTexts[title].firstMatch
        }
        revealMonthlyTask(target, in: app)
        waitUntilHittable(target, message: title + " を長押しできません")
        target.press(forDuration: 1.2)
    }

    private func tapMonthlyTaskDeleteMenu(in app: XCUIApplication) {
        let identified = app.descendants(matching: .any)["monthlyTaskDeleteAction"].firstMatch
        if identified.waitForExistence(timeout: 3) {
            waitUntilHittable(identified, message: "削除を押せません")
            identified.tap()
            return
        }
        let labeled = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "削除")
        ).firstMatch
        XCTAssertTrue(labeled.waitForExistence(timeout: 3), "削除のメニューがありません")
        waitUntilHittable(labeled, message: "削除を押せません")
        labeled.tap()
    }

    private func tapMonthlyTaskAlertButton(_ title: String, in app: XCUIApplication) {
        let alert = app.alerts["タスクを消しますか"].firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "タスクの確認が出ません")
        let button = alert.buttons[title].firstMatch
        waitUntilHittable(button, message: title + " を押せません")
        button.tap()
    }

    /// 最後のタスクが画面の外なら、タスク欄の中だけを滑らせて出す。ログは滑らせない。
    private func revealLastMonthlyTask(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let list = app.scrollViews["monthlyTaskList"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "タスクの一覧がありません")
        var symbol = monthlyTaskButton(label, in: app)
        var attempt = 0
        while attempt < 8 {
            symbol = monthlyTaskButton(label, in: app)
            if symbol.exists, taskSymbolIsAboveKeyboard(symbol, in: app) {
                return symbol
            }
            list.swipeUp()
            attempt += 1
        }
        XCTFail("最後のタスクを一覧の中に出せませんでした")
        return symbol
    }

    /// 記号の枠が、画面の中でキーボードより上になるまで待つ。スクロールはしない。
    ///
    /// 枠が無効なあいだは isHittable を見ない。見ると、それだけでテストが落ちる。
    private func waitForMonthlyTaskSymbolAboveKeyboard(
        _ label: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        var symbol = monthlyTaskButton(label, in: app)
        XCTAssertTrue(symbol.waitForExistence(timeout: 5), "タスクの記号がありません")
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            symbol = monthlyTaskButton(label, in: app)
            if symbol.exists, taskSymbolIsAboveKeyboard(symbol, in: app) {
                return symbol
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("タスクの記号がキーボードの上にありません")
        return symbol
    }

    /// 記号の枠が、画面の中でキーボードより上か。枠が無効なら false。
    private func taskSymbolIsAboveKeyboard(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let frame = element.frame
        if frame.isNull || frame.isInfinite || frame.width < 2 || frame.height < 2 {
            return false
        }
        let window = app.frame
        var visibleBottom = window.maxY
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            let kb = keyboard.frame
            if kb.isNull == false && kb.isInfinite == false && kb.height > 1 && kb.minY.isFinite {
                visibleBottom = min(visibleBottom, kb.minY)
            }
        }
        if frame.minY < window.minY + 1 {
            return false
        }
        if frame.maxY > visibleBottom - 2 {
            return false
        }
        if frame.minX > window.maxX || frame.maxX < window.minX {
            return false
        }
        return true
    }

    /// 画面の外なら、上へ滑らせて見えるようにする。見えているときは滑らせない。
    private func revealMonthlyTask(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "要素がありません")
        var attempt = 0
        while element.isHittable == false && attempt < attempts {
            let ready = NSPredicate(block: { evaluated, _ in
                guard let candidate = evaluated as? XCUIElement else {
                    return false
                }
                return candidate.isHittable
            })
            let expectation = XCTNSPredicateExpectation(predicate: ready, object: element)
            if XCTWaiter().wait(for: [expectation], timeout: 1) == .completed {
                return
            }
            app.swipeUp()
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
