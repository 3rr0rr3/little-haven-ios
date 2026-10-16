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

    func testReceptionDecisionsDoorAndSave() {
        let app = launch("--ui-world")
        XCTAssertTrue(app.buttons["office_door"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["Walk north"].exists, "Reception clerk has no walking controls")
        XCTAssertTrue(app.buttons["chargeGuest"].waitForExistence(timeout:15), "Client walks in and starts a conversation")
        app.buttons["chooseRoom0"].tap()
        app.buttons["chargeGuest"].tap()
        XCTAssertTrue(cash(app).contains("260"))
        XCTAssertTrue(app.buttons["declineGuest"].waitForExistence(timeout:20))
        app.buttons["declineGuest"].tap()
        XCTAssertTrue(cash(app).contains("260"), "Decline must not charge")
        app.buttons["office_save"].tap()
        app.buttons["office_tools"].tap()
        app.buttons["office_door"].tap()
        let world = app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout:10))
        XCTAssertTrue(world.label.contains("MOTEL GROUNDS"))
        let before = world.label
        app.buttons["Walk east"].press(forDuration:0.45)
        XCTAssertNotEqual(world.label,before)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["office_door"].waitForExistence(timeout:10))
        XCTAssertTrue(cash(app).contains("260"))
        capture(app,"Reception decisions and saved desk checkpoint")
    }
    func testFamilyAndCatsAreTappable() {
        let app = launch("--ui-office-family")
        XCTAssertTrue(app.buttons["office_chichu"].waitForExistence(timeout:10))
        app.buttons["office_chichu"].tap()
        XCTAssertTrue(app.alerts["Chichu"].waitForExistence(timeout:3))
        app.alerts.buttons["Pet"].tap()
        app.buttons["office_chichi"].tap()
        XCTAssertTrue(app.alerts["Chichi"].waitForExistence(timeout:3))
        app.alerts.buttons["Give a treat"].tap()
        app.buttons["office_samhil"].tap()
        XCTAssertTrue(app.alerts["Samhil"].waitForExistence(timeout:3))
        app.alerts.buttons["Watch together"].tap()
        app.buttons["office_hildarelys"].tap()
        XCTAssertTrue(app.alerts["Hildarelys"].waitForExistence(timeout:3))
        app.alerts.buttons["Give her a kiss"].tap()
        app.buttons["office_player"].tap()
        XCTAssertTrue(app.buttons["saveCheckpoint"].waitForExistence(timeout:3))
        app.buttons["saveCheckpoint"].tap()
        capture(app,"Expanded office with family, cats, sofa and television")
    }

    func testPhysicalRoomCleaning() {
        let app = launch("--ui-world-clean")
        let world = app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout: 10))
        XCTAssertTrue((world.value as? String ?? "").contains("Cleaning 0/3"))
        app.buttons["worldAction"].press(forDuration: 1.8)
        XCTAssertTrue((world.value as? String ?? "").contains("Cleaning 1/3"), "Cleaning result: \(world.value ?? "missing"), position: \(world.label)")
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
