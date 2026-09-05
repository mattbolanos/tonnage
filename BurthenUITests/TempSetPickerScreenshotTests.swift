import XCTest

final class TempSetPickerScreenshotTests: XCTestCase {
  @MainActor
  func testCaptureSetPicker() throws {
    let app = XCUIApplication()
    app.launch()

    app.buttons["Add Workout"].firstMatch.tap()
    XCTAssertTrue(app.buttons["Blank Workout"].waitForExistence(timeout: 3))
    app.buttons["Blank Workout"].firstMatch.tap()
    XCTAssertTrue(app.buttons["New Exercise"].waitForExistence(timeout: 3))
    app.buttons["New Exercise"].firstMatch.tap()

    let nameField = app.textFields["Name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 3))
    nameField.tap()
    nameField.typeText("Bench Press")
    let weightField = app.textFields["Starting Working Weight (Optional)"]
    weightField.tap()
    weightField.typeText("116")
    app.buttons["Create"].firstMatch.tap()

    XCTAssertTrue(app.buttons["Start Workout"].waitForExistence(timeout: 3))
    app.buttons["Start Workout"].tap()

    XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 3))
    app.staticTexts["Bench Press"].firstMatch.tap()

    XCTAssertTrue(app.buttons["Set 1"].waitForExistence(timeout: 3))
    app.buttons["Set 1"].firstMatch.tap()
    XCTAssertTrue(app.navigationBars["Set 1"].waitForExistence(timeout: 3))
    sleep(1)
    save(app.screenshot(), "01-off")

    let wheels = app.pickerWheels
    if wheels.count >= 2 {
      wheels.element(boundBy: 1).swipeUp()
      sleep(1)
    }

    let apply = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Apply Weight'")).firstMatch
    XCTAssertTrue(apply.waitForExistence(timeout: 3))
    apply.tap()
    sleep(1)
    save(app.screenshot(), "02-on")

    app.buttons["Done"].firstMatch.tap()
    sleep(1)
    save(app.screenshot(), "03-list")
  }

  private func save(_ shot: XCUIScreenshot, _ name: String) {
    try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/burthen-ui/\(name).png"))
  }
}
