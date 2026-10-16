import XCTest

final class LittleHavenUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testHoldReleaseCollisionAndSave() {
        let app = launch("--ui-fresh")
        let map = app.otherElements["townMap"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertTrue(map.label.contains("row 19"))
        app.buttons["Walk north"].press(forDuration: 0.8)
        let stopped = map.label
        XCTAssertFalse(stopped.contains("row 19"))
        XCTAssertFalse(stopped.contains("row 18"))
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(map.label, stopped)
        app.buttons["Open journal"].tap()
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertEqual(map.label, stopped)
        app.buttons["Walk south"].press(forDuration: 4)
        XCTAssertTrue(map.label.contains("row 21"))
    }

    func testWalkOutCollectToolsChargeGuestsAndSave() {
        let app = launch("--ui-wake")
        XCTAssertTrue(app.buttons["wakeUp"].waitForExistence(timeout: 10))
        app.buttons["wakeUp"].tap()
        let world = app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout: 10))
        XCTAssertTrue(world.label.contains("YOUR OFFICE"))
        step("west", 2, app)
        step("north", 2, app)
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "MOP + FRESH SHEETS")).firstMatch.exists)
        step("east", 1, app)
        step("south", 2, app)
        step("east", 1, app)
        step("south", 1, app)
        XCTAssertTrue(world.label.contains("MOTEL GROUNDS"))
        let before = world.label
        app.buttons["Walk east"].press(forDuration: 0.45)
        XCTAssertNotEqual(world.label, before)
        let released = world.label
        Thread.sleep(forTimeInterval: 0.45)
        XCTAssertEqual(world.label, released)
        // Return to the office doorway to normalize the outdoor position.
        // Reset this test fixture to a fresh shift, then leave the office once.
        app.terminate()
        app.launchArguments = ["--ui-world", "--ui-testing"]
        app.launch()
        XCTAssertTrue(world.waitForExistence(timeout: 10))
        step("south", 1, app)
        step("west", 1, app)
        step("south", 1, app)
        XCTAssertTrue(world.label.contains("Column 5, row 11"))
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.buttons["chargeGuest"].waitForExistence(timeout: 5))
        app.buttons["chooseRoom0"].tap()
        app.buttons["chargeGuest"].tap()
        XCTAssertTrue(cash(app).contains("260"), "Unexpected cash counter: \(cash(app))")
        app.buttons["worldAction"].tap()
        app.buttons["chooseRoom1"].tap()
        app.buttons["chargeGuest"].tap()
        XCTAssertTrue(cash(app).contains("420"), "Unexpected cash counter: \(cash(app))")
        capture(app, "Clients in the physical motel grounds")
        step("north", 1, app)
        step("east", 1, app)
        step("north", 1, app)
        XCTAssertTrue(world.label.contains("YOUR OFFICE"))
        step("north", 2, app)
        app.buttons["worldAction"].tap()
        app.buttons["saveCheckpoint"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(world.waitForExistence(timeout: 10))
        XCTAssertTrue(world.label.contains("YOUR OFFICE"))
        XCTAssertTrue(world.label.contains("Column 4, row 5"))
        XCTAssertTrue(cash(app).contains("420"), "Unexpected cash counter: \(cash(app))")
    }

    func testPhysicalRoomCleaning() {
        let app = launch("--ui-world-clean")
        let world = app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout: 10))
        XCTAssertTrue((world.value as? String ?? "").contains("Cleaning 0/3"))
        app.buttons["worldAction"].press(forDuration: 1.8)
        XCTAssertTrue((world.value as? String ?? "").contains("Cleaning 1/3"))
        step("east", 1, app)
        step("south", 2, app)
        app.buttons["worldAction"].press(forDuration: 1.8)
        XCTAssertTrue((world.value as? String ?? "").contains("Cleaning 2/3"))
        step("west", 1, app)
        step("south", 1, app)
        app.buttons["worldAction"].press(forDuration: 1.8)
        XCTAssertTrue((world.value as? String ?? "").contains("Ready for guests"))
        capture(app, "A room cleaned by walking to every task")
    }

    func testObjectCustomizationAndConstruction() {
        let app = launch("--ui-world-decor")
        let world = app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout: 10))
        app.buttons["worldAction"].tap()
        app.buttons["paint2"].tap()
        XCTAssertTrue((world.value as? String ?? "").contains("Theme 2"))
        step("west", 1, app)
        step("south", 1, app)
        step("west", 2, app)
        app.buttons["worldAction"].tap()
        XCTAssertTrue((world.value as? String ?? "").contains("Furnishings 1"))
        capture(app, "Physical furniture and paint interaction")
        app.terminate()
        app.launchArguments = ["--ui-world-build", "--ui-testing"]
        app.launch()
        XCTAssertTrue(world.waitForExistence(timeout: 10))
        app.buttons["worldAction"].tap()
        app.buttons["buildRoom"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "4 ROOMS")).firstMatch.exists)
    }

    func testCaughtRestoresLastCheckpoint() {
        let app = launch("--ui-motel-risk")
        let restore = app.buttons["restoreCheckpoint"]
        XCTAssertTrue(restore.waitForExistence(timeout: 12))
        capture(app, "Caught while sneaking")
        restore.tap()
        let world = app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout: 8))
        XCTAssertTrue(world.label.contains("MOTEL GROUNDS"))
        XCTAssertTrue(cash(app).contains("260"), "Unexpected cash counter: \(cash(app))")
    }

    private func launch(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [fixture, "--ui-testing"]
        app.launch()
        return app
    }
    private func step(_ direction: String, _ count: Int, _ app: XCUIApplication) {
        for _ in 0..<count { app.buttons["Walk " + direction].tap() }
    }
    private func cash(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["motelCash"].firstMatch.label
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
