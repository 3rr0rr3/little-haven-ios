import XCTest

final class LittleHavenUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testHoldReleaseCollisionAndSave() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-fresh"]
        app.launch()
        let map = app.otherElements["townMap"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertTrue(map.label.contains("row 19"))
        app.buttons["Walk north"].press(forDuration: 0.8)
        let stopped = map.label
        XCTAssertFalse(stopped.contains("row 19"))
        XCTAssertFalse(stopped.contains("row 18"), "Holding must travel multiple tiles")
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(map.label, stopped, "Releasing must stop movement")
        app.buttons["Open journal"].tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(map.label, stopped, "Menus must not resume movement")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertEqual(map.label, stopped, "Release must save progress")
        app.buttons["Walk south"].press(forDuration: 4)
        XCTAssertTrue(map.label.contains("row 21"))
    }

    func testWakeUpGuestsDecorateExpandAndSave() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-wake"]
        app.launch()
        XCTAssertTrue(app.buttons["wakeUp"].waitForExistence(timeout: 10))
        capture(app, "Wake-up")
        app.buttons["wakeUp"].tap()
        XCTAssertTrue(app.buttons["checkIn10"].waitForExistence(timeout: 10))
        app.buttons["checkIn10"].tap()
        app.buttons["assignRoom0"].tap()
        app.buttons["checkIn11"].tap()
        app.buttons["assignRoom1"].tap()
        let tabs = app.segmentedControls["motelTabs"]
        tabs.buttons["Rooms"].tap()
        let customize = app.buttons["customizeRoom2"]
        reveal(customize, app)
        customize.tap()
        app.buttons["theme2"].tap()
        let upgrade = app.buttons["upgradeFurniture"]
        reveal(upgrade, app)
        upgrade.tap()
        XCTAssertTrue(app.staticTexts["Furniture / level 2 of 3"].exists)
        capture(app, "Customized motel room")
        app.buttons["Done"].tap()
        let expand = app.buttons["expandMotel"]
        reveal(expand, app)
        XCTAssertTrue(expand.isEnabled)
        expand.tap()
        XCTAssertTrue(app.staticTexts["ROOM 104"].exists)
        // Scroll back to the management controls.
        for _ in 0..<5 { if tabs.isHittable { break }; app.swipeDown() }
        tabs.buttons["Office"].tap()
        let officeEdit = app.buttons["Customize office"]
        reveal(officeEdit, app)
        officeEdit.tap()
        app.buttons["theme1"].tap()
        app.buttons["Done"].tap()
        let save = app.buttons["saveOffice"]
        reveal(save, app)
        save.tap()
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.segmentedControls["motelTabs"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["GOAL  4/9 ROOMS"].exists)
        capture(app, "Motel expansion and restored checkpoint")
    }

    func testCaughtRestoresLastCheckpoint() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-motel-risk"]
        app.launch()
        let restore = app.buttons["restoreCheckpoint"]
        XCTAssertTrue(restore.waitForExistence(timeout: 12), "Suspicion must trigger game over")
        capture(app, "Caught")
        restore.tap()
        XCTAssertTrue(app.segmentedControls["motelTabs"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["motelCash"].firstMatch.label.contains("260"))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "1/3 occupied")).firstMatch.exists)
    }

    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
