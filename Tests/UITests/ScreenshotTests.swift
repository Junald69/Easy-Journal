import XCTest

/// 起動直後の画面を1枚撮る。機種は CI が選んだ iPhone 1台だけ。
final class ScreenshotTests: XCTestCase {
    func testLaunchScreenshot() {
        let app = XCUIApplication()
        // 起動引数の受け取り口に渡すだけ。サンプルデータの中身は、まだ空（T-109）。
        app.launchArguments = ["-sampleData"]
        app.launch()

        let title = app.staticTexts["Easy Journal"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 10),
            "「Easy Journal」が表示されませんでした"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "01-launch"
        // 成功したテストの添付は、標準では消える。画面写真は残す。
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
