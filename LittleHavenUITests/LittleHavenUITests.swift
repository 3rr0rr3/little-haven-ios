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
        XCTAssertTrue(app.buttons["office_door"].waitForExistence(timeout:10), app.debugDescription)
        XCTAssertTrue(app.buttons["Walk north"].exists, "Office has walking controls")
        XCTAssertTrue(app.buttons["office_guest"].waitForExistence(timeout:15))
        Thread.sleep(forTimeInterval:5)
        app.buttons["office_guest"].tap()
        XCTAssertTrue(app.buttons["chargeGuest"].waitForExistence(timeout:15), "Client walks in and starts a conversation")
        app.buttons["chooseRoom0"].tap()
        app.buttons["chargeGuest"].tap()
        XCTAssertTrue(cash(app).contains("260"))
        Thread.sleep(forTimeInterval:9)
        app.buttons["office_guest"].tap()
        XCTAssertTrue(app.buttons["declineGuest"].waitForExistence(timeout:20))
        app.buttons["declineGuest"].tap()
        XCTAssertTrue(cash(app).contains("260"), "Decline must not charge")
        app.buttons["office_save"].tap()
        app.buttons["office_tools"].tap()
        app.buttons["office_door"].tap()
        let world = app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout:10))
        XCTAssertTrue(world.label.contains("Airb&b GROUNDS"))
        let before = world.label
        app.buttons["Walk east"].press(forDuration:0.45)
        XCTAssertNotEqual(world.label,before)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["office_door"].waitForExistence(timeout:10), app.debugDescription)
        XCTAssertTrue(cash(app).contains("260"))
        capture(app,"Reception decisions and saved desk checkpoint")
    }
    func testFamilyAndCatsAreTappable() {
        let app = launch("--ui-office-family")
        XCTAssertTrue(app.buttons["office_chichu"].waitForExistence(timeout:10), app.debugDescription)
        app.buttons["office_chichu"].tap()
        XCTAssertTrue(app.otherElements["gameDialogue"].waitForExistence(timeout:3))
        app.buttons["Pet"].tap()
        app.buttons["office_chichi"].tap()
        XCTAssertTrue(app.otherElements["gameDialogue"].waitForExistence(timeout:3))
        app.buttons["Give a treat"].tap()
        app.buttons["office_samhil"].tap()
        XCTAssertTrue(app.otherElements["gameDialogue"].waitForExistence(timeout:3))
        app.buttons["Watch together"].tap()
        app.buttons["office_hildarelys"].tap()
        XCTAssertTrue(app.otherElements["gameDialogue"].waitForExistence(timeout:3))
        app.buttons["Give her a kiss"].tap()
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
        XCTAssertTrue(world.label.contains("Airb&b GROUNDS"))
        XCTAssertTrue(cash(app).contains("260"), "Unexpected cash counter: \(cash(app))")
    }

    func testStaffReviewsAndDeskUpgrades() {
        let app = launch("--ui-operations")
        XCTAssertTrue(app.buttons["openStaff"].waitForExistence(timeout:10))
        app.buttons["openStaff"].tap()
        app.buttons["hire_cleaner"].tap()
        XCTAssertTrue(cash(app).contains("800"))
        app.buttons["Close interaction"].tap()
        app.buttons["receptionDesk"].tap()
        app.buttons["deskRooms"].tap()
        app.buttons["deskUpgrade_0"].tap()
        XCTAssertTrue(cash(app).contains("710"))
        app.buttons["Close interaction"].tap()
        app.buttons["openReviews"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["guestReview_good"].exists)
        XCTAssertTrue(app.descendants(matching:.any)["guestReview_bad"].exists)
        capture(app,"Good and bad reviews, hired staff and room upgrades")
    }
    func testOutdoorChaosCanBeHandled() {
        let app = launch("--ui-chaos-fire")
        for (fixture,action) in [("--ui-chaos-fire","Put out the fire"),("--ui-chaos-pool","Help the guest out"),("--ui-chaos-fight","Break up the fight")] {
            if fixture != "--ui-chaos-fire" { app.terminate(); app.launchArguments = [fixture,"--ui-testing"]; app.launch() }
            XCTAssertTrue(app.buttons["incidentAlarm"].waitForExistence(timeout:10))
            app.buttons["worldAction"].tap()
            XCTAssertTrue(app.otherElements["gameDialogue"].waitForExistence(timeout:3))
            app.buttons[action].tap()
            XCTAssertFalse(app.buttons["incidentAlarm"].exists)
        }
    }
    func testPoliceFineAndBribe() {
        let app = launch("--ui-police")
        XCTAssertTrue(app.buttons["Risk a bribe / 80"].waitForExistence(timeout:10))
        app.buttons["Risk a bribe / 80"].tap()
        XCTAssertTrue(cash(app).contains("780"))
        XCTAssertTrue(app.buttons["Pay fine / 350"].waitForExistence(timeout:3))
        capture(app,"Police refuse bribe after a fatal emergency")
        app.buttons["Pay fine / 350"].tap()
        XCTAssertTrue(cash(app).contains("430"))
        XCTAssertFalse(app.buttons["policeAlarm"].exists)
    }
    func testProminentHiringButton() {
        let app = launch("--ui-operations")
        XCTAssertTrue(app.buttons["hireEmployees"].waitForExistence(timeout:10))
        app.buttons["hireEmployees"].tap()
        XCTAssertTrue(app.buttons["hire_cleaner"].waitForExistence(timeout:3))
        capture(app,"Visible hiring panel")
    }
    func testCarWashPaysOnlyOnce() {
        let app=launch("--ui-parking")
        XCTAssertTrue(app.buttons["washCar"].waitForExistence(timeout:10))
        let before=cash(app)
        XCTAssertTrue(before.contains("900"))
        app.buttons["washCar"].tap()
        XCTAssertTrue(cash(app).contains("935"))
        XCTAssertFalse(app.buttons["washCar"].exists)
        capture(app,"Car washed with animated foam and spray")
    }
    func testWeatherAndAnimatedTheft() {
        let app=launch("--ui-weather-storm")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@", "THUNDERSTORM")).firstMatch.waitForExistence(timeout:10))
        capture(app,"Storm particles outside the hotel")
        app.terminate(); app.launchArguments=["--ui-action-theft","--ui-testing"]; app.launch()
        XCTAssertTrue(app.descendants(matching:.any)["motelWorld"].waitForExistence(timeout:10))
        capture(app,"Recognizable suitcase, watch and camera in the guest room")
    }
    func testManagementBoardSuppliesAndMiniGame() {
        let app=launch("--ui-management")
        XCTAssertTrue(app.buttons["openManagement"].waitForExistence(timeout:10))
        app.buttons["openManagement"].tap()
        XCTAssertTrue(app.buttons["miniClean_1"].waitForExistence(timeout:5))
        app.buttons["miniClean_1"].tap()
        XCTAssertTrue(app.buttons["miniGameTap"].waitForExistence(timeout:3))
        app.buttons["Cancel"].tap()
        app.buttons["manageTab_Supplies"].tap()
        XCTAssertTrue(app.buttons["buy_toiletries"].waitForExistence(timeout:3))
        app.buttons["buy_toiletries"].tap()
        XCTAssertTrue(app.staticTexts["In stock: 16"].exists)
        capture(app,"Management inventory and ongoing supply costs")
    }
    func testManagementUtilitiesAndCameras() {
        let app=launch("--ui-management-events")
        XCTAssertTrue(app.buttons["restoreUtilities"].waitForExistence(timeout:10))
        app.buttons["restoreUtilities"].tap()
        XCTAssertFalse(app.buttons["restoreUtilities"].exists)
        capture(app,"Actionable power and pest complaints")
        app.terminate();app.launchArguments=["--ui-management-cameras","--ui-testing"];app.launch()
        XCTAssertTrue(app.descendants(matching:.any)["cameraMonitor"].waitForExistence(timeout:10))
        XCTAssertTrue(app.buttons["Disable night vision"].exists)
        app.buttons["Disable night vision"].tap()
        XCTAssertTrue(app.buttons["Enable night vision"].exists)
        capture(app,"Live grounds cameras and night vision")
    }
    func testManagementDayNightAndPricing() {
        let app=launch("--ui-management-night")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@", "22:00 NIGHT")).firstMatch.waitForExistence(timeout:10))
        capture(app,"Night shift hotel grounds")
        app.buttons["openManagement"].tap()
        app.buttons["manageTab_Desk"].tap()
        XCTAssertTrue(app.segmentedControls["pricingPolicy"].waitForExistence(timeout:5))
        capture(app,"Hourly nightly and weekly pricing")
    }
    func testTitleOptionsContinueAndNewGame() {
        let app=launch("--ui-title")
        XCTAssertTrue(app.buttons["titleOptions"].waitForExistence(timeout:10))
        app.buttons["titleOptions"].tap()
        XCTAssertTrue(app.switches["optionHints"].waitForExistence(timeout:5))
        app.switches["optionHints"].tap()
        app.buttons["Done"].tap()
        app.buttons["titleOptions"].tap()
        XCTAssertEqual(app.switches["optionHints"].value as? String,"0")
        app.buttons["Restore default options"].tap()
        app.buttons["Done"].tap()
        app.buttons["titleQuit"].tap()
        app.buttons["Quit session"].tap()
        XCTAssertTrue(app.buttons["returnTitle"].waitForExistence(timeout:5))
        app.buttons["returnTitle"].tap()
        if !app.buttons["newGame"].exists {
            app.buttons["startGame"].tap()
            app.terminate();app.launchArguments=["--ui-title","--ui-testing"];app.launch()
        }
        app.buttons["newGame"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["startGame"].exists)
        app.buttons["newGame"].tap()
        app.buttons["Erase checkpoint and start new game"].tap()
        XCTAssertTrue(app.otherElements["townMap"].waitForExistence(timeout:10))
        XCTAssertTrue(app.otherElements["townMap"].label.contains("row 19"))
        capture(app,"New adventure starts from zero")
    }
    func testOfficeWalkingStopsOnRelease() {
        let app=launch("--ui-office-family")
        let office=app.otherElements["officeScene"]
        XCTAssertTrue(office.waitForExistence(timeout:10))
        let before=office.value as? String
        app.buttons["Walk east"].press(forDuration:0.45)
        let after=office.value as? String
        XCTAssertNotEqual(before,after)
        Thread.sleep(forTimeInterval:0.7)
        XCTAssertEqual(office.value as? String,after,"Release stops movement even as reception ticks")
        capture(app,"Free office movement")
    }
    func testOutdoorControlsStayPutNearTasks() {
        let app=launch("--ui-parking")
        let arrow=app.buttons["Walk west"]
        XCTAssertTrue(arrow.waitForExistence(timeout:10))
        let frame=arrow.frame
        let world=app.otherElements["motelWorld"]
        arrow.press(forDuration:0.65)
        let stopped=world.label
        Thread.sleep(forTimeInterval:0.7)
        XCTAssertEqual(world.label,stopped)
        XCTAssertEqual(arrow.frame,frame,"Nearby actions cannot shift the D-pad")
        app.buttons["Walk east"].press(forDuration:0.4)
        let stoppedAgain=world.label
        Thread.sleep(forTimeInterval:0.7)
        XCTAssertEqual(world.label,stoppedAgain)
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
