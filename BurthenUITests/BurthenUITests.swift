//
//  BurthenUITests.swift
//  BurthenUITests
//
//  Created by Matt Bolaños on 7/25/26.
//

import XCTest

final class BurthenUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCanOpenExerciseManagementFromLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        let exerciseName = "UI Exercise \(UUID().uuidString.prefix(8))"
        app.launch()

        app.tabBars.buttons["Library"].tap()
        app.staticTexts["Exercises"].tap()

        XCTAssertTrue(app.navigationBars["Exercises"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.navigationBars["Exercises"].buttons["Edit"].exists)

        app.navigationBars["Exercises"].buttons["Add Exercise"].tap()

        XCTAssertTrue(app.navigationBars["New Exercise"].waitForExistence(timeout: 2))
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText(exerciseName)
        app.navigationBars["New Exercise"].buttons["Create"].tap()

        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 2))
        app.staticTexts[exerciseName].tap()

        XCTAssertTrue(app.navigationBars["Edit Exercise"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["Name"].value as? String, exerciseName)
    }

    @MainActor
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
