import XCTest

final class WorkoutFlowUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testEditingProgressionAndWorkoutCompletion() throws {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    app.buttons["Add Workout"].tap()
    app.buttons["Blank Workout"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Test Press", weight: "100")

    app.navigationBars["Blank Workout"].buttons["Add Exercises"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Test Row", weight: "50")
    app.navigationBars["Exercises"].buttons["Add"].tap()
    app.buttons["Start Workout"].tap()

    let finish = app.buttons["Finish Workout"]
    XCTAssertTrue(finish.waitForExistence(timeout: 5))
    XCTAssertFalse(finish.isEnabled)
    app.staticTexts["Test Press"].tap()
    app.buttons["Set 1"].tap()

    let done = app.buttons["Done"]
    XCTAssertTrue(done.waitForExistence(timeout: 3))
    XCTAssertTrue(done.isHittable)
    XCTAssertFalse(app.buttons["Set as Starting Weight…"].exists)
    capture(app, named: "Set editor")

    app.switches["Half pounds"].tap()
    app.buttons["Set Options"].tap()
    app.buttons["Set as Starting Weight…"].tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS %@", "every set after this one"
    )).firstMatch.waitForExistence(timeout: 3))
    app.buttons["Save and Update Sets"].tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS %@", "Following sets updated."
    )).firstMatch.waitForExistence(timeout: 3))
    done.tap()

    XCTAssertTrue(app.buttons["Set 1"].waitForExistence(timeout: 3))
    for number in 1...3 {
      let value = try XCTUnwrap(app.buttons["Set \(number)"].value as? String)
      XCTAssertTrue(value.contains("Not completed"))
      XCTAssertTrue(value.contains("100.5 pounds"))
    }
    XCTAssertFalse(app.buttons["Next Exercise: Test Row"].exists)
    completeWorkingSets(in: app)

    let next = app.buttons["Next Exercise: Test Row"]
    XCTAssertTrue(next.waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Add Set"].exists)
    capture(app, named: "Next exercise")
    next.tap()
    XCTAssertTrue(app.navigationBars["Test Row"].waitForExistence(timeout: 3))

    // Advancing replaces the exercise destination: Back goes to the overview.
    app.navigationBars["Test Row"].buttons.element(boundBy: 0).tap()
    XCTAssertTrue(finish.waitForExistence(timeout: 3))
    app.staticTexts["Test Row"].tap()
    completeWorkingSets(in: app)
    app.buttons["Review Workout"].tap()
    XCTAssertTrue(finish.waitForExistence(timeout: 3))
    XCTAssertTrue(finish.isEnabled)
    finish.tap()

    XCTAssertTrue(app.navigationBars["Workout Summary"].waitForExistence(timeout: 5))
    let completion = app.descendants(matching: .any).matching(NSPredicate(
      format: "label CONTAINS %@", "6 sets completed"
    )).firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 3))
    XCTAssertFalse(app.tabBars.buttons["Workout"].exists)
    capture(app, named: "Completed workout")

    app.buttons["Save as Template"].tap()
    XCTAssertTrue(app.navigationBars["New Template"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Test Press"].exists)
    XCTAssertTrue(app.staticTexts["Test Row"].exists)
    app.buttons["Cancel"].tap()
    app.navigationBars["Workout Summary"].buttons.element(boundBy: 0).tap()
    app.cells.buttons.firstMatch.tap()
    XCTAssertTrue(app.navigationBars["Workout Summary"].waitForExistence(timeout: 3))
    XCTAssertFalse(completion.exists, "Opening history should not repeat the completion acknowledgment.")
  }

  @MainActor
  func testSetEditorAtLargestAccessibilityTextSize() throws {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing",
      "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    app.launch()

    app.buttons["Add Workout"].tap()
    app.buttons["Blank Workout"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Large Text Press", weight: "100")
    app.buttons["Start Workout"].tap()
    app.staticTexts["Large Text Press"].tap()
    app.buttons["Set 1"].tap()

    let done = app.buttons["Done"]
    XCTAssertTrue(done.waitForExistence(timeout: 3))
    XCTAssertTrue(done.isHittable)
    XCTAssertEqual(app.pickerWheels.count, 0)
    XCTAssertTrue(app.descendants(matching: .any)["set-repetitions"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["set-weight"].exists)
    capture(app, named: "Set editor at maximum text size")
    done.tap()
    XCTAssertTrue(app.buttons["Set 1"].waitForExistence(timeout: 3))
    let value = try XCTUnwrap(app.buttons["Set 1"].value as? String)
    XCTAssertTrue(value.contains("Not completed"))
  }

  @MainActor
  private func createExercise(in app: XCUIApplication, name: String, weight: String) {
    let nameField = app.textFields["Name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 3))
    nameField.tap()
    nameField.typeText(name)
    let weightField = app.textFields["Starting Working Weight (Optional)"]
    if !weightField.isHittable {
      app.swipeUp()
    }
    weightField.tap()
    weightField.typeText(weight)
    app.navigationBars["New Exercise"].buttons["Create"].tap()
  }

  @MainActor
  private func completeWorkingSets(in app: XCUIApplication) {
    for _ in 0..<3 {
      app.buttons["Complete Set"].firstMatch.tap()
    }
  }

  @MainActor
  private func capture(_ app: XCUIApplication, named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
