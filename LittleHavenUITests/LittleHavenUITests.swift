import XCTest

final class LittleHavenUITests: XCTestCase {
    func testHoldReleaseCollisionAndSave() {
        let app = XCUIApplication()
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
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertEqual(map.label, stopped, "Release must save progress")
        app.buttons["Walk south"].press(forDuration: 4)
        XCTAssertTrue(map.label.contains("row 21"), "Continuous movement must stop at the town boundary")
        let boundary = map.label
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(map.label, boundary)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Cut-paper characters and hold controls"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
