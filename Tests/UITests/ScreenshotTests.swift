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

    /// 10月→11月→10月。移った先に、前の月の行とタスクは出ない。戻ると残っている。
    ///
    /// 26日に書いた文字は、月を移るときに保存され、戻っても残る。
    func testMonthNavigationRoundTripKeepsEachMonthSeparate() {
        let app = launchMonthly()
        waitForMonthlyLog(app)
        waitForMonthTitle("2026年 10月", in: app)

        let field = openMonthlyField(app, dateKey: "2026-10-26")
        field.typeText("StayOct")
        goToMonth(button: "monthlyNextButton", title: "2026年 11月", in: app)

        let novemberRow = app.descendants(matching: .any)["monthlyLogRow-2026-11-01"]
        XCTAssertTrue(novemberRow.waitForExistence(timeout: 10), "11月1日の行がありません")
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-10-26"].exists,
            "10月の行が11月に残っています"
        )
        XCTAssertFalse(
            monthlyTaskButton("未完 今月のねらい", in: app).exists,
            "10月のタスクが11月に出ています"
        )
        attachScreenshot(app, name: "07-monthly-november")

        goToMonth(button: "monthlyPreviousButton", title: "2026年 10月", in: app)
        waitUntilTextShows(app, dateKey: "2026-10-26", text: "StayOct")
        XCTAssertTrue(
            monthlyTaskButton("未完 今月のねらい", in: app).waitForExistence(timeout: 5),
            "10月に戻っても、元のタスクがありません"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "11月の行が10月に残っています"
        )
    }

    /// 12月→翌年1月→12月。タイトルと、その月の行だけが変わる。
    func testMonthNavigationCrossesYear() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore",
            "-openPage",
            "monthly:2026-12",
            "-todayKey",
            "2026-10-27",
        ]
        app.launch()
        let screen = app.descendants(matching: .any)["monthlyLogScreen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "12月の画面がありません")
        waitForMonthTitle("2026年 12月", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["monthlyLogRow-2026-12-01"].waitForExistence(timeout: 10),
            "12月1日の行がありません"
        )

        goToMonth(button: "monthlyNextButton", title: "2027年 1月", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["monthlyLogRow-2027-01-01"].waitForExistence(timeout: 10),
            "1月1日の行がありません"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-12-01"].exists,
            "12月の行が1月に残っています"
        )

        goToMonth(button: "monthlyPreviousButton", title: "2026年 12月", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["monthlyLogRow-2026-12-01"].waitForExistence(timeout: 10),
            "12月に戻ったあとの行がありません"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2027-01-01"].exists,
            "1月の行が12月に残っています"
        )
    }

    /// 空にした下書きは、確認なしで消さない。月も移さない。
    /// タスク追加欄の未確定の文字も、捨てて月を移さない。
    ///
    /// アラートとボタンは firstMatch。押す前に isHittable を待つ。
    /// キーボードが開いていると、◀▶ の最初の1回はキーボードを閉じるだけで、移動や確認まで進まないことがある。
    /// そのときは、もう一度押す。
    func testMonthMoveKeepsDeleteConfirmationAndTaskDraft() {
        let dateKey = "2026-10-24"
        let app = launchMonthly()
        waitForMonthlyLog(app)

        let field = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: field, knownText: "資料", app: app)
        tapMonthButton("monthlyNextButton", in: app)
        var alert = app.alerts["この行を消しますか？"].firstMatch
        if alert.waitForExistence(timeout: 3) == false {
            tapMonthButton("monthlyNextButton", in: app)
            alert = app.alerts["この行を消しますか？"].firstMatch
        }
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "行を消す確認が出ません")
        waitForMonthTitle("2026年 10月", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "確認の前に月が移りました"
        )

        let cancel = alert.buttons["キャンセル"].firstMatch
        waitUntilHittable(cancel, message: "キャンセルを押せません")
        cancel.tap()
        waitUntilGone(alert, message: "確認が閉じません")
        waitUntilTextShows(app, dateKey: dateKey, text: "資料")
        waitForMonthTitle("2026年 10月", in: app)

        let addButton = app.descendants(matching: .any)["monthlyTaskAddButton"].firstMatch
        revealMonthlyTask(addButton, in: app)
        waitUntilHittable(addButton, message: "タスクの追加を押せません")
        addButton.tap()
        let taskField = app.textFields["monthlyTaskTitleField"].firstMatch
        waitUntilHittable(taskField, message: "タスクの名前欄を押せません")
        taskField.tap()
        taskField.typeText("KeepMe")
        // キーボードが開いていると、最初のタップはキーボードを閉じるだけで、月の移動は走らない。
        // 閉じたあとのタップで、未確定のタスク名が残って月が動かないことを見る。
        tapMonthButton("monthlyNextButton", in: app)
        tapMonthButton("monthlyNextButton", in: app)
        waitForMonthTitle("2026年 10月", in: app)
        let shown = taskField.value as? String ?? ""
        XCTAssertTrue(shown.contains("KeepMe"), "未確定のタスク名が消えました: " + shown)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "未確定のタスク名があるのに月が移りました"
        )

        let confirm = app.descendants(matching: .any)["monthlyTaskConfirmButton"].firstMatch
        revealMonthlyTask(confirm, in: app)
        waitUntilHittable(confirm, message: "タスクの追加の確定を押せません")
        confirm.tap()
        let created = monthlyTaskButton("未完 KeepMe", in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 5), "追加後のタスクがありません")
        waitUntilHittable(created, message: "追加したタスクを押せません")
        created.tap()
        XCTAssertTrue(
            monthlyTaskButton("一部 KeepMe", in: app).waitForExistence(timeout: 5),
            "タスクの状態が変わりません"
        )

        goToMonth(button: "monthlyNextButton", title: "2026年 11月", in: app)
        XCTAssertFalse(monthlyTaskButton("一部 KeepMe", in: app).exists, "10月のタスクが11月に出ています")
        goToMonth(button: "monthlyPreviousButton", title: "2026年 10月", in: app)
        XCTAssertTrue(
            monthlyTaskButton("一部 KeepMe", in: app).waitForExistence(timeout: 5),
            "10月に戻っても、追加したタスクがありません"
        )
        waitUntilTextShows(app, dateKey: dateKey, text: "資料")
    }

    /// 月を移す確認で「キャンセル」と「消す」。どちらも、その場の月のまま。
    ///
    /// キーボードが開いていると、最初の1回はキーボードを閉じるだけ、のことがある。
    func testMonthMoveDeleteConfirmationCancelAndDelete() {
        let dateKey = "2026-10-24"
        let app = launchMonthly()
        waitForMonthlyLog(app)

        let field = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: field, knownText: "資料", app: app)
        let alert = waitForMonthMoveDeleteAlert(in: app)
        let cancel = alert.buttons["キャンセル"].firstMatch
        waitUntilHittable(cancel, message: "キャンセルを押せません")
        cancel.tap()
        waitUntilGone(alert, message: "確認が閉じません")
        waitUntilTextShows(app, dateKey: dateKey, text: "資料")
        waitForMonthTitle("2026年 10月", in: app)

        let fieldAgain = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: fieldAgain, knownText: "資料", app: app)
        let alertAgain = waitForMonthMoveDeleteAlert(in: app)
        let confirm = alertAgain.buttons["消す"].firstMatch
        waitUntilHittable(confirm, message: "消すを押せません")
        confirm.tap()
        waitUntilGone(alertAgain, message: "確認が閉じません")
        waitUntilTextHides(app, dateKey: dateKey, text: "資料")
        waitForMonthTitle("2026年 10月", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "確認のあと、まだ月が移っています"
        )

        goToMonth(button: "monthlyNextButton", title: "2026年 11月", in: app)
    }

    /// 一言日記の編集中に、タスク名の未確定があると、月は移らない。
    /// 両方の文字と、一言日記の編集欄が残る。案内だけ出る。
    func testMonthMoveTaskDraftKeepsLogEditorAndShowsMessage() {
        let dateKey = "2026-10-26"
        let app = launchMonthly(includeSampleData: false)
        waitForMonthlyLog(app)

        let addButton = app.descendants(matching: .any)["monthlyTaskAddButton"].firstMatch
        revealMonthlyTask(addButton, in: app)
        waitUntilHittable(addButton, message: "タスクの追加を押せません")
        addButton.tap()
        let taskField = app.textFields["monthlyTaskTitleField"].firstMatch
        waitUntilHittable(taskField, message: "タスクの名前欄を押せません")
        taskField.tap()
        taskField.typeText("KeepTask")

        let field = openMonthlyField(app, dateKey: dateKey)
        field.typeText("KeepLog")
        tapMonthButton("monthlyNextButton", in: app)
        tapMonthButton("monthlyNextButton", in: app)

        waitForMonthTitle("2026年 10月", in: app)
        let message = app.descendants(matching: .any)["monthlyTaskDraftBlockMessage"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5), "止めた理由が出ません")
        XCTAssertTrue(
            message.label.contains("タスクを追加するか、入力を消してから月を移動してください"),
            "案内の文が違います"
        )
        let logField = app.descendants(matching: .textField)["monthlyLogText-" + dateKey]
        XCTAssertTrue(logField.waitForExistence(timeout: 5), "一言日記の編集欄が閉じました")
        let logShown = logField.value as? String ?? ""
        XCTAssertTrue(logShown.contains("KeepLog"), "編集中の文字が消えました: " + logShown)
        let taskShown = taskField.value as? String ?? ""
        XCTAssertTrue(taskShown.contains("KeepTask"), "未確定のタスク名が消えました: " + taskShown)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "未確定のまま月が移りました"
        )
    }

    /// 移る先の読み込みに失敗したら、月は移らない。成功した再試行で、その案内は消える。
    func testMonthMoveLoadFailureClearsWhenRetrySucceeds() {
        let app = launchMonthly(extraArguments: ["-failMonthMove", "load"])
        waitForMonthlyLog(app)
        tapMonthButton("monthlyNextButton", in: app)
        waitForMonthTitle("2026年 10月", in: app)
        let loadError = app.descendants(matching: .any)["monthlyLoadError"].firstMatch
        XCTAssertTrue(loadError.waitForExistence(timeout: 5), "読み込みの失敗が出ません")
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlySaveError"].exists,
            "読み込みの失敗なのに、保存の失敗が出ています"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["monthlyLogRow-2026-10-01"].waitForExistence(timeout: 5),
            "失敗で、今の月の行が消えました"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "読み込みに失敗したのに月が移りました"
        )

        goToMonth(button: "monthlyNextButton", title: "2026年 11月", in: app)
        let lingering = app.descendants(matching: .any)["monthlyLoadError"].firstMatch
        XCTAssertFalse(lingering.exists, "成功したあとも、読み込みの失敗が残っています")
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlySaveError"].exists,
            "成功したあとに、保存の失敗が出ています"
        )
    }

    /// 移る先の保存に失敗したら、月は移らない。成功した再試行で、その案内は消える。
    func testMonthMoveSaveFailureClearsWhenRetrySucceeds() {
        let app = launchMonthly(extraArguments: ["-failMonthMove", "save"])
        waitForMonthlyLog(app)
        tapMonthButton("monthlyNextButton", in: app)
        waitForMonthTitle("2026年 10月", in: app)
        let saveError = app.descendants(matching: .any)["monthlySaveError"].firstMatch
        XCTAssertTrue(saveError.waitForExistence(timeout: 5), "保存の失敗が出ません")
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLoadError"].exists,
            "保存の失敗なのに、読み込みの失敗が出ています"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "保存に失敗したのに月が移りました"
        )

        goToMonth(button: "monthlyNextButton", title: "2026年 11月", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlySaveError"].exists,
            "成功したあとも、保存の失敗が残っています"
        )
    }

    /// 外から月を開く依頼でも、◀▶ と同じ保存のあとで、表示はその月になる。
    /// 編集中の1行は、書き始めた日に残り、開いた先の月には出ない。
    func testExternalMonthChangeMatchesRouterAndKeepsSourceLine() {
        let app = launchMonthly(extraArguments: ["-debugJumpMonth", "2026-11"])
        waitForMonthlyLog(app)
        let field = openMonthlyField(app, dateKey: "2026-10-26")
        field.typeText("FromOct")

        let jump = app.descendants(matching: .any)["debugJumpMonth"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "外部からの月移動がありません")
        waitUntilHittable(jump, message: "外部からの月移動を押せません")
        jump.tap()
        if app.descendants(matching: .any)["monthlyTitle"].label != "2026年 11月" {
            waitUntilHittable(jump, message: "外部からの月移動を押せません")
            jump.tap()
        }
        waitForMonthTitle("2026年 11月", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].waitForExistence(timeout: 10),
            "Router の月と、表示の行が違います"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-10-26"].exists,
            "10月の行が11月に出ています"
        )

        goToMonth(button: "monthlyPreviousButton", title: "2026年 10月", in: app)
        waitUntilTextShows(app, dateKey: "2026-10-26", text: "FromOct")
    }

    /// 一言日記の保存に失敗したら、外からの月移動は止まる。下書きは見えたまま、編集を続けられる。
    func testExternalLogSaveFailureKeepsDraftAndAllowsEditing() {
        let dateKey = "2026-10-26"
        let app = launchMonthly(
            extraArguments: ["-failMonthMove", "log", "-debugJumpMonth", "2026-11"],
            includeSampleData: false
        )
        waitForMonthlyLog(app)
        let field = openMonthlyField(app, dateKey: dateKey)
        field.typeText("KeepDraft")

        requestDebugMonth(in: app, untilMarker: "monthlySaveError")
        waitForMonthTitle("2026年 10月", in: app)
        let saveError = app.descendants(matching: .any)["monthlySaveError"].firstMatch
        XCTAssertTrue(saveError.waitForExistence(timeout: 5), "保存の失敗が出ません")
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "保存に失敗したのに月が移りました"
        )
        let shown = field.value as? String ?? ""
        XCTAssertTrue(shown.contains("KeepDraft"), "失敗した下書きが見えません: " + shown)

        field.tap()
        field.typeText("More")
        let resumed = field.value as? String ?? ""
        XCTAssertTrue(resumed.contains("KeepDraftMore"), "編集を再開できません: " + resumed)

        goToMonth(button: "monthlyNextButton", title: "2026年 11月", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-10-26"].exists,
            "10月の行が11月に出ています"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlySaveError"].exists,
            "成功したあとも、保存の失敗が残っています"
        )
        goToMonth(button: "monthlyPreviousButton", title: "2026年 10月", in: app)
        waitUntilTextShows(app, dateKey: dateKey, text: "KeepDraftMore")
    }

    /// タスク名の未確定があると、外からの月移動も止まる。一言日記の編集も残る。
    func testExternalTaskDraftBlocksMove() {
        let dateKey = "2026-10-26"
        let app = launchMonthly(
            extraArguments: ["-debugJumpMonth", "2026-11"],
            includeSampleData: false
        )
        waitForMonthlyLog(app)

        let addButton = app.descendants(matching: .any)["monthlyTaskAddButton"].firstMatch
        revealMonthlyTask(addButton, in: app)
        waitUntilHittable(addButton, message: "タスクの追加を押せません")
        addButton.tap()
        let taskField = app.textFields["monthlyTaskTitleField"].firstMatch
        waitUntilHittable(taskField, message: "タスクの名前欄を押せません")
        taskField.tap()
        taskField.typeText("ExtTask")

        let field = openMonthlyField(app, dateKey: dateKey)
        field.typeText("ExtLog")
        requestDebugMonth(in: app, untilMarker: "monthlyTaskDraftBlockMessage")

        waitForMonthTitle("2026年 10月", in: app)
        let message = app.descendants(matching: .any)["monthlyTaskDraftBlockMessage"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5), "止めた理由が出ません")
        let logShown = field.value as? String ?? ""
        XCTAssertTrue(logShown.contains("ExtLog"), "編集中の文字が消えました: " + logShown)
        let taskShown = taskField.value as? String ?? ""
        XCTAssertTrue(taskShown.contains("ExtTask"), "未確定のタスク名が消えました: " + taskShown)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "未確定のまま月が移りました"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyTaskLabel-ExtTask"].exists,
            "未確定のタスクが保存されました"
        )
    }

    /// 外からの月移動でも、削除確認のキャンセルは記録を残す。「消す」はその行だけ消して、月は移さない。
    func testExternalDeleteConfirmationCancelKeepsLineAndDeleteRemovesOnlyThatLine() {
        let dateKey = "2026-10-24"
        let app = launchMonthly(extraArguments: ["-debugJumpMonth", "2026-11"])
        waitForMonthlyLog(app)

        let field = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: field, knownText: "資料", app: app)
        let alert = waitForExternalDeleteAlert(in: app)
        let fromMove = app.descendants(matching: .any)["monthlyLogDeleteFromMonthMove"]
        let blocked = app.descendants(matching: .any)["monthlyMoveBlockedByConfirm"]
        XCTAssertTrue(
            fromMove.exists || blocked.exists,
            "確認が、月の移動からなのか、焦点が外れたからなのか分かりません"
        )
        let cancel = alert.buttons["キャンセル"].firstMatch
        waitUntilHittable(cancel, message: "キャンセルを押せません")
        cancel.tap()
        waitUntilGone(alert, message: "確認が閉じません")
        waitUntilTextShows(app, dateKey: dateKey, text: "資料")
        waitUntilTextShows(app, dateKey: "2026-10-01", text: "月初")
        waitForMonthTitle("2026年 10月", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "キャンセルのあとに月が移りました"
        )

        let fieldAgain = openMonthlyField(app, dateKey: dateKey)
        deleteAllCharacters(in: fieldAgain, knownText: "資料", app: app)
        let alertAgain = waitForExternalDeleteAlert(in: app)
        let fromMoveAgain = app.descendants(matching: .any)["monthlyLogDeleteFromMonthMove"]
        let blockedAgain = app.descendants(matching: .any)["monthlyMoveBlockedByConfirm"]
        XCTAssertTrue(
            fromMoveAgain.exists || blockedAgain.exists,
            "2回目の確認の出どころが分かりません"
        )
        let confirm = alertAgain.buttons["消す"].firstMatch
        waitUntilHittable(confirm, message: "消すを押せません")
        confirm.tap()
        waitUntilGone(alertAgain, message: "確認が閉じません")
        waitUntilTextHides(app, dateKey: dateKey, text: "資料")
        waitUntilTextShows(app, dateKey: "2026-10-01", text: "月初")
        waitForMonthTitle("2026年 10月", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)["monthlyLogRow-2026-11-01"].exists,
            "消したあとに月が移りました"
        )
    }

    /// 止めたタスク名を消すと、一言日記の編集欄に焦点が戻る。
    func testClearingBlockedTaskDraftRestoresLogEditor() {
        let dateKey = "2026-10-26"
        let app = launchMonthly(includeSampleData: false)
        waitForMonthlyLog(app)

        // ＋ を先に押す。日記を開いたまま ＋ を押すと、その日記は保存されて閉じる。
        let addButton = app.descendants(matching: .any)["monthlyTaskAddButton"].firstMatch
        revealMonthlyTask(addButton, in: app)
        waitUntilHittable(addButton, message: "タスクの追加を押せません")
        addButton.tap()
        let taskField = app.textFields["monthlyTaskTitleField"].firstMatch
        waitUntilHittable(taskField, message: "タスクの名前欄を押せません")
        taskField.tap()
        taskField.typeText("Temp")

        let field = openMonthlyField(app, dateKey: dateKey)
        field.typeText("FocusLog")
        tapMonthButton("monthlyNextButton", in: app)
        tapMonthButton("monthlyNextButton", in: app)
        let message = app.descendants(matching: .any)["monthlyTaskDraftBlockMessage"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5), "止めた理由が出ません")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "止めた時点で一言日記の編集欄が閉じました")
        let blockedText = field.value as? String ?? ""
        XCTAssertTrue(blockedText.contains("FocusLog"), "止めた時点で下書きが消えました: " + blockedText)

        clearTaskTitle(taskField, knownText: "Temp", app: app)
        let logField = app.descendants(matching: .textField)["monthlyLogText-" + dateKey]
        var scrolls = 0
        while logField.exists == false && scrolls < 3 {
            app.swipeDown()
            scrolls += 1
        }
        XCTAssertTrue(logField.waitForExistence(timeout: 5), dateKey + " の編集欄がありません")
        let logStill = logField.value as? String ?? ""
        XCTAssertTrue(logStill.contains("FocusLog"), "一言日記の編集欄が閉じました: " + logStill)

        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let ready = XCTNSPredicateExpectation(predicate: focused, object: logField)
        XCTAssertEqual(
            XCTWaiter().wait(for: [ready], timeout: 5),
            .completed,
            "一言日記の編集欄に焦点が戻りません"
        )
        logField.typeText("Z")
        let resumed = logField.value as? String ?? ""
        XCTAssertTrue(resumed.contains("FocusLogZ"), "焦点を戻した欄に書けません: " + resumed)
        waitForMonthTitle("2026年 10月", in: app)
    }

    /// タスク欄で止めたあとタスクを追加したら、次の日記は焦点が外れたときに保存して閉じる。
    func testAfterTaskBlockAddingTaskRestoresFocusLossSave() {
        let app = launchMonthly(includeSampleData: false)
        waitForMonthlyLog(app)

        let addButton = app.descendants(matching: .any)["monthlyTaskAddButton"].firstMatch
        revealMonthlyTask(addButton, in: app)
        waitUntilHittable(addButton, message: "タスクの追加を押せません")
        addButton.tap()
        let taskField = app.textFields["monthlyTaskTitleField"].firstMatch
        revealMonthlyTask(taskField, in: app)
        waitUntilHittable(taskField, message: "タスクの名前欄を押せません")
        taskField.tap()
        taskField.typeText("HoldTask")

        let first = openMonthlyField(app, dateKey: "2026-10-26")
        first.typeText("StayOpen")
        tapMonthButton("monthlyNextButton", in: app)
        tapMonthButton("monthlyNextButton", in: app)
        let message = app.descendants(matching: .any)["monthlyTaskDraftBlockMessage"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5), "止めた理由が出ません")

        let confirm = app.descendants(matching: .any)["monthlyTaskConfirmButton"].firstMatch
        revealMonthlyTask(confirm, in: app)
        waitUntilHittable(confirm, message: "タスクの追加の確定を押せません")
        confirm.tap()
        XCTAssertTrue(
            monthlyTaskButton("未完 HoldTask", in: app).waitForExistence(timeout: 5),
            "止めたあとのタスクが追加されません"
        )
        let closedFirst = app.descendants(matching: .textField)["monthlyLogText-2026-10-26"]
        XCTAssertFalse(closedFirst.exists, "タスクを追加したあとも、最初の日記が編集のままです")

        let second = openMonthlyField(app, dateKey: "2026-10-25")
        second.typeText("NextLine")
        // 別の行を押すと、前の行を保存してからその行を開く。
        // キーボードを閉じるだけの操作は、この画面には確定的な入口が無い。
        tapMonthlyText(app, dateKey: "2026-10-24")
        waitForMonthTitle("2026年 10月", in: app)
        let stillEditing = app.descendants(matching: .textField)["monthlyLogText-2026-10-25"]
        let closed = NSPredicate(format: "exists == false")
        let closedExpectation = XCTNSPredicateExpectation(predicate: closed, object: stillEditing)
        XCTAssertEqual(
            XCTWaiter().wait(for: [closedExpectation], timeout: 5),
            .completed,
            "別の行へ移したあとも、前の編集欄が閉じていません"
        )
        waitUntilTextShows(app, dateKey: "2026-10-25", text: "NextLine")
        waitForMonthTitle("2026年 10月", in: app)
    }

    /// 12月から翌年1月、1月から前年12月へ、外からの依頼でも表示と行がその月になる。
    func testExternalMonthCrossesYear() {
        let forward = XCUIApplication()
        forward.launchArguments = [
            "-inMemoryStore",
            "-openPage",
            "monthly:2026-12",
            "-todayKey",
            "2026-12-15",
            "-debugJumpMonth",
            "2027-01",
        ]
        forward.launch()
        XCTAssertTrue(
            forward.descendants(matching: .any)["monthlyLogScreen"].waitForExistence(timeout: 10),
            "12月の画面がありません"
        )
        waitForMonthTitle("2026年 12月", in: forward)
        XCTAssertTrue(
            forward.descendants(matching: .any)["monthlyLogRow-2026-12-01"].waitForExistence(timeout: 10),
            "12月1日の行がありません"
        )
        tapDebugJump(untilTitle: "2027年 1月", in: forward)
        XCTAssertTrue(
            forward.descendants(matching: .any)["monthlyLogRow-2027-01-01"].waitForExistence(timeout: 10),
            "1月1日の行がありません"
        )
        XCTAssertFalse(
            forward.descendants(matching: .any)["monthlyLogRow-2026-12-01"].exists,
            "12月の行が1月に出ています"
        )
        forward.terminate()

        let backward = XCUIApplication()
        backward.launchArguments = [
            "-inMemoryStore",
            "-openPage",
            "monthly:2027-01",
            "-todayKey",
            "2027-01-02",
            "-debugJumpMonth",
            "2026-12",
        ]
        backward.launch()
        XCTAssertTrue(
            backward.descendants(matching: .any)["monthlyLogScreen"].waitForExistence(timeout: 10),
            "1月の画面がありません"
        )
        waitForMonthTitle("2027年 1月", in: backward)
        tapDebugJump(untilTitle: "2026年 12月", in: backward)
        XCTAssertTrue(
            backward.descendants(matching: .any)["monthlyLogRow-2026-12-31"].waitForExistence(timeout: 10),
            "12月31日の行がありません"
        )
        XCTAssertFalse(
            backward.descendants(matching: .any)["monthlyLogRow-2027-01-01"].exists,
            "1月の行が12月に出ています"
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

    /// 空の行を消す確認が出るまで、◀▶ を押す。
    ///
    /// キーボードが開いていると、最初の1回はキーボードを閉じるだけ、のことがある。
    private func waitForMonthMoveDeleteAlert(in app: XCUIApplication) -> XCUIElement {
        tapMonthButton("monthlyNextButton", in: app)
        var alert = app.alerts["この行を消しますか？"].firstMatch
        if alert.waitForExistence(timeout: 3) == false {
            tapMonthButton("monthlyNextButton", in: app)
            alert = app.alerts["この行を消しますか？"].firstMatch
        }
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "行を消す確認が出ません")
        return alert
    }

    private func waitForMonthTitle(_ title: String, in app: XCUIApplication) {
        let element = app.descendants(matching: .any)["monthlyTitle"]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "月のタイトルがありません")
        let matched = NSPredicate(format: "label == %@", title)
        let expectation = XCTNSPredicateExpectation(predicate: matched, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 10),
            .completed,
            "月のタイトルが " + title + " になりません"
        )
    }

    /// ◀▶。キーボードが開いていると、最初のタップはキーボードを閉じるだけ、のことがある。
    /// タイトルが変わるまで、押せる状態を待ってから、最大3回押す。
    private func goToMonth(button identifier: String, title: String, in app: XCUIApplication) {
        var attempt = 0
        while attempt < 3 {
            tapMonthButton(identifier, in: app)
            let element = app.descendants(matching: .any)["monthlyTitle"]
            if element.waitForExistence(timeout: 2), element.label == title {
                return
            }
            attempt += 1
        }
        waitForMonthTitle(title, in: app)
    }

    /// 外からの月移動。キーボードが最初のタップを取るときは、印が出るまでもう一度押す。
    /// 印が出たあとは押さない。失敗の注入を、成功する再試行で消さないため。
    private func requestDebugMonth(in app: XCUIApplication, untilMarker identifier: String) {
        let jump = app.descendants(matching: .any)["debugJumpMonth"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "外部からの月移動がありません")
        var attempt = 0
        while attempt < 3 {
            let marker = app.descendants(matching: .any)[identifier].firstMatch
            if marker.exists {
                return
            }
            waitUntilHittable(jump, message: "外部からの月移動を押せません")
            jump.tap()
            if marker.waitForExistence(timeout: 2) {
                return
            }
            attempt += 1
        }
        let marker = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 5), identifier + " が出ません")
    }

    /// 外からの月移動で、タイトルが変わるまで押す。すでにその月なら押さない。
    private func tapDebugJump(untilTitle title: String, in app: XCUIApplication) {
        let jump = app.descendants(matching: .any)["debugJumpMonth"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "外部からの月移動がありません")
        var attempt = 0
        while attempt < 3 {
            let element = app.descendants(matching: .any)["monthlyTitle"]
            if element.waitForExistence(timeout: 2), element.label == title {
                return
            }
            waitUntilHittable(jump, message: "外部からの月移動を押せません")
            jump.tap()
            attempt += 1
        }
        waitForMonthTitle(title, in: app)
    }

    /// 外からの月移動で、空の行を消す確認が出るまで押す。
    private func waitForExternalDeleteAlert(in app: XCUIApplication) -> XCUIElement {
        let jump = app.descendants(matching: .any)["debugJumpMonth"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "外部からの月移動がありません")
        waitUntilHittable(jump, message: "外部からの月移動を押せません")
        jump.tap()
        var alert = app.alerts["この行を消しますか？"].firstMatch
        if alert.waitForExistence(timeout: 3) == false {
            waitUntilHittable(jump, message: "外部からの月移動を押せません")
            jump.tap()
            alert = app.alerts["この行を消しますか？"].firstMatch
        }
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "行を消す確認が出ません")
        return alert
    }

    private func tapMonthButton(_ identifier: String, in app: XCUIApplication) {
        let button = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), identifier + " がありません")
        waitUntilHittable(button, message: identifier + " を押せません")
        button.tap()
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

    /// タスク名を、delete キーで空にする。空と、欄の案内「タスク」は入力なしとみなす。
    ///
    /// 全文の一部だけ消えると、未確定のまま残り、焦点は戻らない。空になってから次へ進む。
    private func clearTaskTitle(_ field: XCUIElement, knownText: String, app: XCUIApplication) {
        var attempt = 0
        while attempt < 4 {
            let shown = field.value as? String ?? ""
            if isClearedTaskTitle(shown) && attempt > 0 {
                break
            }
            if shown == "タスク" {
                break
            }
            let deleteCount = knownText.count
            let endOfField = field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5))
            endOfField.tap()
            let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount)
            field.typeText(deletes)
            attempt += 1
        }
        let afterDeletes = field.value as? String ?? ""
        if isClearedTaskTitle(afterDeletes) == false {
            selectAllThenDelete(in: field, app: app)
        }
        let leftover = field.value as? String ?? ""
        XCTAssertTrue(isClearedTaskTitle(leftover), "タスク名が空ではありません: " + leftover)
    }

    /// 入力が残っていないとき true。案内の「タスク」だけは空とみなす。
    private func isClearedTaskTitle(_ shown: String) -> Bool {
        if shown.isEmpty || shown == "タスク" {
            return true
        }
        return false
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
