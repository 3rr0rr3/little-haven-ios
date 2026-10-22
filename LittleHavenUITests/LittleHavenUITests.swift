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
        let doorFrame = app.buttons["office_door"].frame
        app.buttons["office_save"].tap()
        app.buttons["office_tools"].tap()
        XCTAssertEqual(app.buttons["office_door"].frame, doorFrame, "Notifications must not shift room touch targets")
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
        let app = launch("--ui-family-home")
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

    func testHomeDesignerAndFurniturePurchase() {
        let app=launch("--ui-home-store")
        XCTAssertTrue(app.buttons["worldAction"].waitForExistence(timeout:10))
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.otherElements["shopInterior"].waitForExistence(timeout:10))
        step("north",6,app)
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.buttons["buy_home_plant"].waitForExistence(timeout:5))
        app.buttons["buy_home_plant"].tap()
        capture(app,"Furniture shop purchases paid from motel profits")
        app.terminate();app.launchArguments=["--ui-testing","--ui-family-home"];app.launch()
        XCTAssertTrue(app.buttons["office_workbench"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["openHomeDesigner"].exists)
        for _ in 0..<3 { app.buttons["Walk west"].tap() }
        app.buttons["office_workbench"].tap()
        XCTAssertTrue(app.buttons["upgradeHome"].waitForExistence(timeout:5))
        app.buttons["upgradeHome"].tap()
        capture(app,"Home upgrades wallpaper flooring and furniture placement")
    }
    func testPetsFollowOutsideAndWaitIndependently() {
        let app=launch("--ui-family-home")
        XCTAssertTrue(app.buttons["office_chichu"].waitForExistence(timeout:10))
        app.buttons["office_chichu"].tap()
        app.buttons["Follow me"].tap()
        app.buttons["office_chichi"].tap()
        app.buttons["Follow me"].tap()
        app.buttons["office_door"].tap()
        XCTAssertTrue(app.buttons["Chichu"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Chichi"].exists)
        app.buttons["Chichu"].tap()
        XCTAssertTrue(app.buttons["Stay here"].waitForExistence(timeout:3))
        app.buttons["Stay here"].tap()
        for _ in 0..<3 { app.buttons["Walk south"].tap() }
        XCTAssertFalse(app.buttons["Chichu"].exists)
        XCTAssertTrue(app.buttons["Chichi"].exists)
        capture(app,"Chichi follows outside while Chichu waits near home")
    }
    func testPawnShopRequiresExplicitSale() {
        let app=launch("--ui-pawn-store")
        XCTAssertTrue(app.buttons["worldAction"].waitForExistence(timeout:10))
        XCTAssertTrue(cash(app).contains("2500"))
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.otherElements["shopInterior"].waitForExistence(timeout:10))
        step("north",6,app)
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.buttons["pawn_sell_1"].waitForExistence(timeout:5))
        app.buttons["pawn_sell_1"].tap()
        XCTAssertFalse(app.buttons["pawn_sell_1"].exists)
        capture(app,"Pawn shop sells carried items individually")
        app.buttons["Close"].tap()
        XCTAssertTrue(cash(app).contains("2570"))
    }
    func testClothingShopBuysAndEquips() {
        let app=launch("--ui-clothes-store")
        XCTAssertTrue(app.buttons["worldAction"].waitForExistence(timeout:10))
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.otherElements["shopInterior"].waitForExistence(timeout:10))
        step("north",6,app)
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.buttons["outfit_2"].waitForExistence(timeout:5))
        app.buttons["outfit_2"].tap()
        XCTAssertEqual(app.buttons["outfit_2"].label,"Wearing")
        capture(app,"Clothing shop owned and equipped outfits")
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
        step("west", 2, app)
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
        step("west", 3, app)
        step("north", 1, app)
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
        XCTAssertTrue(app.buttons["hireEmployees"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["openStaff"].exists)
        app.buttons["hireEmployees"].tap()
        app.buttons["hire_cleaner"].tap()
        XCTAssertTrue(cash(app).contains("800"))
        app.buttons["Close interaction"].tap()
        XCTAssertTrue(app.buttons["openStaff"].exists)
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
            XCTAssertTrue(app.staticTexts["EMERGENCY"].exists)
            capture(app,"Emergency alert " + fixture)
            app.buttons["incidentAlarm"].tap()
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
        XCTAssertTrue(app.buttons["office_computer"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["openManagement"].exists)
        app.buttons["office_computer"].tap()
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
        app.buttons["office_computer"].tap()
        app.buttons["manageTab_Desk"].tap()
        XCTAssertTrue(app.segmentedControls["pricingPolicy"].waitForExistence(timeout:5))
        capture(app,"Hourly nightly and weekly pricing")
    }
    func testTitleOptionsContinueAndNewGame() {
        let app=XCUIApplication()
        app.launchArguments=["--ui-title","--ui-office-family","--ui-testing"]; app.launch()
        XCTAssertTrue(app.buttons["OPTIONS"].waitForExistence(timeout:10))
        app.buttons["OPTIONS"].tap()
        XCTAssertTrue(app.switches["optionHints"].waitForExistence(timeout:5))
        let hintSwitch = app.switches["optionHints"]
        let originalHintValue = hintSwitch.value as? String
        let expectedHintValue = originalHintValue == "1" ? "0" : "1"
        hintSwitch.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap()
        Thread.sleep(forTimeInterval:0.5)
        if (hintSwitch.value as? String) == originalHintValue {
            hintSwitch.coordinate(withNormalizedOffset:CGVector(dx:0.78,dy:0.5)).tap()
        }
        expectation(for: NSPredicate(format:"value == %@", expectedHintValue), evaluatedWith:hintSwitch)
        waitForExpectations(timeout:3)
        let changedHintValue = hintSwitch.value as? String
        XCTAssertEqual(changedHintValue, expectedHintValue)
        app.buttons["Done"].tap()
        app.buttons["OPTIONS"].tap()
        XCTAssertEqual(app.switches["optionHints"].value as? String, changedHintValue)
        let defaults=app.buttons["Restore default options"]
        if !defaults.isHittable { app.swipeUp() }
        defaults.tap()
        app.buttons["Done"].tap()
        app.buttons["QUIT"].tap()
        app.buttons["Quit session"].tap()
        XCTAssertTrue(app.buttons["RETURN TO TITLE"].waitForExistence(timeout:5))
        app.buttons["RETURN TO TITLE"].tap()
        app.buttons["CONTINUE GAME"].tap()
        XCTAssertTrue(app.otherElements["officeScene"].waitForExistence(timeout:10),"Continue loads existing hotel")
        app.buttons["Pause game"].tap()
        app.buttons["Options"].tap()
        XCTAssertTrue(app.switches["optionHints"].waitForExistence(timeout:5),"In-game options opens from pause")
        app.buttons["Done"].tap()
        app.buttons["backToTitle"].tap()
        XCTAssertTrue(app.buttons["CONTINUE GAME"].waitForExistence(timeout:10))
        app.buttons["NEW GAME"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["CONTINUE GAME"].exists)
        app.buttons["NEW GAME"].tap()
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
    func testShortDpadTapMovesImmediatelyAndStops() {
        let app=launch("--ui-office-family")
        let office=app.otherElements["officeScene"]
        XCTAssertTrue(office.waitForExistence(timeout:10))
        let before=office.value as? String
        app.buttons["Walk east"].tap()
        let after=office.value as? String
        XCTAssertNotEqual(before,after,"A quick tap starts the first step without a hold delay")
        Thread.sleep(forTimeInterval:0.5)
        XCTAssertEqual(office.value as? String,after,"A short tap does not keep walking")
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
    func testWalkingPastDoorActionsKeepsMoving() {
        let app=launch("--ui-guest-favour")
        let world=app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout:10))
        app.buttons["Walk east"].press(forDuration:1.6)
        let label=world.label
        let column=Int(label.components(separatedBy:"Column ").last?.components(separatedBy:",").first ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(column,24,"A held direction continues through nearby room actions")
        Thread.sleep(forTimeInterval:0.5)
        XCTAssertEqual(world.label,label,"Releasing still stops immediately")
    }
    func testGuestConversationCanAcceptAPersonalRequest() {
        let app=launch("--ui-guest-favour")
        let talk=app.buttons["talkToGuest"]
        XCTAssertTrue(talk.waitForExistence(timeout:10))
        talk.tap()
        let promise=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@", "Promise to bring")).firstMatch
        XCTAssertTrue(promise.waitForExistence(timeout:5))
        capture(app,"Guest conversation and personal request")
        promise.tap()
        XCTAssertFalse(promise.exists)
        XCTAssertTrue(app.buttons["Walk east"].exists)
    }
    func testBeachIsReachableAndDecorated() {
        let app=launch("--ui-beach")
        let world=app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["SUNSET COVE BEACH"].exists)
        let before=world.label
        app.buttons["Walk east"].press(forDuration:0.5)
        XCTAssertNotEqual(world.label,before)
        capture(app,"Sunset Cove palms umbrellas loungers and sea")
    }
    func testShopInteriorExitReturnsToItsOwnDoor() {
        let app=launch("--ui-home-store")
        XCTAssertTrue(app.buttons["worldAction"].waitForExistence(timeout:10))
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.otherElements["shopInterior"].waitForExistence(timeout:10))
        XCTAssertTrue(app.buttons["shopCounter"].exists)
        app.buttons["Walk south"].tap()
        let world=app.otherElements["motelWorld"]
        XCTAssertTrue(world.waitForExistence(timeout:5))
        XCTAssertTrue(world.label.contains("Column 47"))
    }
    func testBarBartenderServesDrinks() {
        let app=launch("--ui-bar")
        XCTAssertTrue(app.otherElements["shopInterior"].waitForExistence(timeout:10))
        XCTAssertTrue(app.buttons["barPatron0"].exists)
        app.buttons["shopCounter"].tap()
        let drink=app.buttons["orderDrink_citrusSoda"]
        XCTAssertTrue(drink.waitForExistence(timeout:5))
        drink.tap()
        XCTAssertTrue(app.staticTexts["492 COINS"].exists)
        XCTAssertTrue(app.descendants(matching:.any).matching(NSPredicate(format:"label CONTAINS %@", "Jules served: Citrus soda")).firstMatch.exists)
        capture(app,"Bartender serves drink in lively bar")
    }
    func testBeachChairCanRelaxAndStand() {
        let app=launch("--ui-chair")
        XCTAssertTrue(app.buttons["standFromChair"].waitForExistence(timeout:10))
        app.buttons["standFromChair"].tap()
        XCTAssertTrue(app.buttons["sitOnChair"].waitForExistence(timeout:3))
        app.buttons["sitOnChair"].tap()
        XCTAssertTrue(app.buttons["standFromChair"].waitForExistence(timeout:3))
        app.buttons["Walk south"].tap()
        XCTAssertFalse(app.buttons["standFromChair"].exists)
        capture(app,"Beach lounger sit stand and movement")
    }
    func testFullscreenJoystickReleaseAndPause() {
        let app=XCUIApplication()
        app.launchArguments=["--ui-world","--ui-touch","--ui-testing"]
        app.launch()
        let position=app.descendants(matching:.any)["touchPosition"].firstMatch
        XCTAssertTrue(position.waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.buttons["Walk north"].exists)
        let before=position.value as? String
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.55,dy:0.53))
        let east=app.coordinate(withNormalizedOffset:CGVector(dx:0.75,dy:0.53))
        start.tap()
        Thread.sleep(forTimeInterval:0.5)
        XCTAssertEqual(position.value as? String,before,"Ground taps do not start destination walking")
        start.press(forDuration:0.05,thenDragTo:east,withVelocity:.slow,thenHoldForDuration:0.4)
        XCTAssertEqual(position.value as? String,before,"Map dragging no longer moves the character")
        let stick=app.descendants(matching:.any)["fullscreenJoystick"].firstMatch
        XCTAssertTrue(stick.exists)
        let center=stick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        let right=stick.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5))
        center.press(forDuration:0.05,thenDragTo:right,withVelocity:.slow,thenHoldForDuration:0.5)
        XCTAssertNotEqual(position.value as? String,before,"The visible joystick steers continuously")
        let released=position.value as? String
        Thread.sleep(forTimeInterval:0.5)
        XCTAssertEqual(position.value as? String,released,"Releasing the finger stops without walking to its destination")
        center.press(forDuration:0.05,thenDragTo:stick.coordinate(withNormalizedOffset:CGVector(dx:0.1,dy:0.5)),withVelocity:.slow,thenHoldForDuration:0.4)
        XCTAssertNotEqual(position.value as? String,released,"A fresh drag can reverse direction")
        app.buttons["Pause game"].tap()
        let stopped=position.value as? String
        Thread.sleep(forTimeInterval:0.4)
        XCTAssertEqual(position.value as? String,stopped,"Pause cancels movement")
        capture(app,"Full screen visible joystick and release")
    }
    func testFullscreenPrologueJournalAndOptions() {
        let app=XCUIApplication()
        app.launchArguments=["--ui-fresh","--ui-touch","--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Open journal"].waitForExistence(timeout:15))
        XCTAssertFalse(app.buttons["Walk north"].exists)
        app.buttons["Open journal"].tap()
        XCTAssertTrue(app.buttons["Options"].waitForExistence(timeout:5),app.debugDescription)
        app.buttons["Options"].tap()
        XCTAssertTrue(app.switches["optionFullscreenTouch"].waitForExistence(timeout:5))
        capture(app,"Full screen setting and prologue menu")
    }
    func testCreatureCanFollowAndStay() {
        let app=launch("--ui-creature")
        let creature=app.buttons["office_mochi"]
        XCTAssertTrue(creature.waitForExistence(timeout:10))
        creature.tap()
        XCTAssertTrue(app.buttons["Follow me"].waitForExistence(timeout:3))
        app.buttons["Follow me"].tap()
        creature.tap()
        XCTAssertTrue(app.buttons["Stay here"].waitForExistence(timeout:3))
        capture(app,"Reference creature companion")
        app.buttons["Stay here"].tap()
        creature.tap()
        XCTAssertTrue(app.buttons["Follow me"].waitForExistence(timeout:3))
    }
    func testHomeBasementStairsReturnHome() {
        let app=launch("--ui-home-stairs")
        XCTAssertTrue(app.buttons["office_basement"].waitForExistence(timeout:10))
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["basementScene"].firstMatch.waitForExistence(timeout:5))
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.buttons["office_basement"].waitForExistence(timeout:5))
        capture(app,"Home stairs enter and leave basement")
    }
    func testBasementCreatureFeedingAndPetting() {
        let app=XCUIApplication()
        app.launchArguments=["--ui-basement","--ui-corral-0","--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Feed"].waitForExistence(timeout:10))
        app.buttons["Feed"].tap()
        app.buttons["worldAction"].tap()
        XCTAssertTrue(app.buttons["Fed today"].waitForExistence(timeout:3))
        app.buttons["Pet"].tap()
        capture(app,"Eight corral sanctuary and animal care")
    }
    func testRideAndParkBicycle() {
        let app=launch("--ui-bike")
        XCTAssertTrue(app.buttons["rideBike"].waitForExistence(timeout:10))
        app.buttons["rideBike"].tap()
        XCTAssertTrue(app.buttons["dismountBike"].waitForExistence(timeout:3))
        app.buttons["Walk east"].tap()
        capture(app,"Character riding bicycle")
        app.buttons["dismountBike"].tap()
        XCTAssertTrue(app.buttons["rideBike"].waitForExistence(timeout:3))
    }
    func testFishRestaurantServesMeal() {
        let app=launch("--ui-fish")
        XCTAssertTrue(app.buttons["fishDiner0"].waitForExistence(timeout:10))
        app.buttons["shopCounter"].tap()
        XCTAssertTrue(app.buttons["orderMeal_grilledFish"].waitForExistence(timeout:3))
        app.buttons["orderMeal_grilledFish"].tap()
        XCTAssertTrue(app.staticTexts["482 COINS"].exists)
        capture(app,"Fish restaurant order and diners")
    }
    func testCreativeEditorOpensAndMovesWasher() {
        let app=XCUIApplication()
        app.launchArguments=["--ui-creative","--ui-touch","--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["openCreative"].waitForExistence(timeout:15))
        app.buttons["openCreative"].tap()
        XCTAssertTrue(app.buttons["closeCreative"].waitForExistence(timeout:10))
        let washer=app.descendants(matching:.any)["creative-washer"].firstMatch
        XCTAssertTrue(washer.waitForExistence(timeout:5))
        let origin=washer.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        origin.press(forDuration:0.6,thenDragTo:origin.withOffset(CGVector(dx:0,dy:192)))
        XCTAssertTrue(app.staticTexts["Washing machine placed."].waitForExistence(timeout:5),app.debugDescription)
        capture(app,"Creative mode physical object relocation")
        app.buttons["closeCreative"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["fullscreenJoystick"].firstMatch.waitForExistence(timeout:5))
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
        app.descendants(matching: .any)["motelCash"].firstMatch.label.replacingOccurrences(of:",",with:"")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
