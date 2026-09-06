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

    XCTAssertTrue(app.tabBars.buttons["Home"].exists)
    XCTAssertTrue(app.tabBars.buttons["Library"].exists)
    XCTAssertEqual(app.tabBars.buttons.count, 2)
    app.buttons["Start Workout"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Test Press", weight: "100")

    app.navigationBars["Blank Workout"].buttons["Add Exercises"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Test Row", weight: "50")
    app.buttons["Add 1 Exercise"].tap()
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

    app.buttons["Minimize Workout"].tap()
    XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.tabBars.buttons["Library"].exists)
    XCTAssertEqual(app.tabBars.buttons.count, 2)
    capture(app, named: "Active workout accessory")
    app.tabBars.buttons["Library"].tap()
    app.buttons["active-workout-accessory"].tap()
    XCTAssertTrue(app.navigationBars["Test Row"].waitForExistence(timeout: 3))
    app.buttons["Minimize Workout"].tap()
    XCTAssertTrue(app.tabBars.buttons["Library"].isSelected)
    capture(app, named: "Library with active workout")
    app.buttons["active-workout-accessory"].tap()

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
      format: "label CONTAINS %@", "Workout Complete"
    )).firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["summary-completed-sets"].exists)
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
  func testExistingExercisesUseTheSamePickerForWorkoutsAndTemplates() throws {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    XCTAssertTrue(app.buttons["Start Workout"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Create a Template"].exists)
    capture(app, named: "First workout entry")
    app.buttons["Start Workout"].tap()
    XCTAssertFalse(app.buttons["Save as Template"].exists)
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Library Press", weight: "100")
    app.navigationBars["Blank Workout"].buttons["Add Exercises"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Library Row", weight: "50")
    app.buttons["Add 1 Exercise"].tap()
    app.navigationBars["Blank Workout"].buttons.element(boundBy: 0).tap()

    app.buttons["Start Workout"].tap()
    XCTAssertTrue(app.staticTexts["Choose Your Exercises"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Add Exercises"].isHittable)
    capture(app, named: "Choose existing exercises")
    app.buttons["Add Exercises"].tap()
    selectLibraryExercises(in: app)
    capture(app, named: "Shared exercise picker")
    app.buttons["Add 2 Exercises"].tap()
    XCTAssertTrue(app.staticTexts["Library Press"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Library Row"].exists)

    app.buttons["Save as Template"].tap()
    XCTAssertTrue(app.navigationBars["New Template"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Library Press"].exists)
    XCTAssertTrue(app.staticTexts["Library Row"].exists)
    app.buttons["Cancel"].tap()
    app.navigationBars["Blank Workout"].buttons.element(boundBy: 0).tap()

    app.tabBars.buttons["Library"].tap()
    app.staticTexts["Workout Templates"].tap()
    app.navigationBars["Workout Templates"].buttons["Add Template"].tap()
    app.buttons["Add Exercises"].tap()
    selectLibraryExercises(in: app)
    app.buttons["Add 2 Exercises"].tap()
    XCTAssertTrue(app.navigationBars["New Template"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Library Press"].exists)
    XCTAssertTrue(app.staticTexts["Library Row"].exists)
  }

  @MainActor
  func testPartialWorkoutExplainsWhatAppearsInTheSummary() throws {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    app.buttons["Start Workout"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Completed Press", weight: "100")
    app.buttons["Start Workout"].tap()
    XCTAssertTrue(app.buttons["Finish Workout"].waitForExistence(timeout: 5))

    app.buttons["Add Exercise"].tap()
    XCTAssertTrue(app.navigationBars["Add Exercises"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.searchFields.firstMatch.exists)
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Skipped Row", weight: "50")
    app.buttons["Add 1 Exercise"].tap()

    app.staticTexts["Completed Press"].tap()
    app.buttons["Complete Set"].firstMatch.tap()
    app.navigationBars["Completed Press"].buttons.element(boundBy: 0).tap()
    let explanation = app.descendants(matching: .any)["workout-finish-explanation"]
    XCTAssertTrue(explanation.waitForExistence(timeout: 3))
    XCTAssertTrue(explanation.label.contains("1 completed set"))
    XCTAssertTrue(explanation.label.contains("won’t appear in the summary"))
    capture(app, named: "Finish explains unfinished work")
    app.buttons["Finish Workout"].tap()

    XCTAssertTrue(app.navigationBars["Workout Summary"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["summary-completed-sets"].label, "1 set completed")
    XCTAssertTrue(app.descendants(matching: .any)["summary-duration"].exists)
    XCTAssertTrue(app.staticTexts["Completed Press"].exists)
    XCTAssertFalse(app.staticTexts["Skipped Row"].exists)
    XCTAssertFalse(app.buttons["active-workout-accessory"].exists)
    capture(app, named: "Achievement summary")
    app.descendants(matching: .any)["summary-volume-details"].tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS %@", "Volume adds weight"
    )).firstMatch.waitForExistence(timeout: 3))
    capture(app, named: "Volume details")
  }

  @MainActor
  func testDiscardingWorkoutRemovesAccessoryAndKeepsNavigation() throws {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    app.buttons["Start Workout"].tap()
    app.buttons["New Exercise"].tap()
    createExercise(in: app, name: "Discarded Press", weight: "100")
    app.buttons["Start Workout"].tap()
    XCTAssertTrue(app.buttons["Finish Workout"].waitForExistence(timeout: 5))
    app.buttons["Minimize Workout"].tap()
    XCTAssertTrue(app.buttons["active-workout-accessory"].waitForExistence(timeout: 3))
    app.buttons["active-workout-accessory"].tap()
    app.buttons["More"].tap()
    app.buttons["Discard Workout"].tap()
    app.buttons["Discard Workout"].tap()
    XCTAssertTrue(app.buttons["Start Workout"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["active-workout-accessory"].exists)
    XCTAssertEqual(app.tabBars.buttons.count, 2)
    XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
    XCTAssertTrue(app.tabBars.buttons["Library"].exists)
    capture(app, named: "Home after discarding workout")
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

    app.buttons["Start Workout"].tap()
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
    app.buttons["Minimize Workout"].tap()
    let accessory = app.buttons["active-workout-accessory"]
    XCTAssertTrue(accessory.waitForExistence(timeout: 3))
    XCTAssertTrue(accessory.isHittable)
    capture(app, named: "Active workout at maximum text size")
    accessory.tap()
    XCTAssertTrue(app.navigationBars["Large Text Press"].waitForExistence(timeout: 3))
  }

  @MainActor
  private func selectLibraryExercises(in app: XCUIApplication) {
    XCTAssertTrue(app.navigationBars["Add Exercises"].waitForExistence(timeout: 3))
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.exists)
    search.tap()
    search.typeText("Press")
    app.buttons["Library Press"].tap()
    XCTAssertEqual(app.buttons["Library Press"].value as? String, "Selected")
    XCTAssertFalse(app.buttons["Library Row"].exists)
    search.tap()
    search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
    search.typeText("Row")
    app.buttons["Library Row"].tap()
    XCTAssertTrue(app.buttons["Add 2 Exercises"].exists)
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
