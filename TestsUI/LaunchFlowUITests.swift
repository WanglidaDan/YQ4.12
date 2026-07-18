import XCTest

final class LaunchFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-sample"]
        app.launch()
    }

    func testPrimaryWorkflowScreens() throws {
        XCTAssertTrue(app.tabBars.buttons["工作台"].waitForExistence(timeout: 5))
        capture("01-workbench")

        app.buttons["新建档期"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["新建档期"].waitForExistence(timeout: 3))
        capture("02-new-booking")
        app.buttons["取消"].tap()

        openTab("档期")
        capture("03-schedule")

        openTab("客户")
        capture("04-clients")

        openTab("跟进")
        capture("05-follow-up")

        let firstTask = app.staticTexts["核对论坛分工板"]
        for _ in 0..<5 where firstTask.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(firstTask.waitForExistence(timeout: 3))
        firstTask.swipeRight()
        let completeButton = app.buttons["完成"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 2))
        completeButton.tap()
        XCTAssertTrue(app.buttons["撤销"].waitForExistence(timeout: 2))
        capture("06-follow-up-undo")

        openTab("我的")
        capture("07-profile")
    }

    func testAuthenticationScreen() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-auth"]
        app.launch()

        XCTAssertTrue(app.buttons["本机使用"].waitForExistence(timeout: 5))
        capture("00-auth")
    }

    private func openTab(_ title: String) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 3))
        tab.tap()
        XCTAssertTrue(tab.isSelected)
    }

    private func capture(_ name: String) {
        RunLoop.current.run(until: .now.addingTimeInterval(0.7))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
