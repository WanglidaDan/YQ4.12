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

    func testBookingCreationWorkflow() throws {
        XCTAssertTrue(app.tabBars.buttons["工作台"].waitForExistence(timeout: 5))

        app.buttons["新建档期"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["新建档期"].waitForExistence(timeout: 3))

        let clientButton = app.buttons["booking-client"]
        XCTAssertTrue(clientButton.waitForExistence(timeout: 3))
        clientButton.tap()

        let sampleClient = app.buttons["宋知意"]
        XCTAssertTrue(sampleClient.waitForExistence(timeout: 3))
        sampleClient.tap()

        let venueField = app.textFields["booking-venue"]
        XCTAssertTrue(venueField.waitForExistence(timeout: 3))
        venueField.tap()
        venueField.typeText("静安香格里拉")

        let feeField = app.textFields["booking-fee"]
        XCTAssertTrue(feeField.waitForExistence(timeout: 3))
        let nextButton = app.keyboards.buttons["next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
        nextButton.tap()
        feeField.typeText("8800")

        let keyboardDoneButton = app.buttons["booking-keyboard-done"]
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 3))
        keyboardDoneButton.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        app.swipeDown()
        capture("booking-filled")

        let createButton = app.buttons["booking-create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.tap()

        XCTAssertFalse(app.navigationBars["新建档期"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["新建档期"].firstMatch.waitForExistence(timeout: 3))
        capture("booking-saved")
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
