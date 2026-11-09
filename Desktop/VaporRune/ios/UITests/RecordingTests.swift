import XCTest

final class RecordingTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNativeCapturePauseSaveSearchAndPlayback() {
        let app = launch(reset: true)
        let start = app.buttons["startRecordingButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()

        let pause = app.buttons["pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 15), app.debugDescription)
        capture("Recording", in: app)
        waitForLabel(app.staticTexts["recordingTimer"], toChangeFrom: "00:00")
        pause.tap()
        let resume = app.buttons["resumeButton"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        let pausedTime = app.staticTexts["recordingTimer"].label
        let frozen = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", pausedTime),
            object: app.staticTexts["recordingTimer"]
        )
        frozen.isInverted = true
        wait(for: [frozen], timeout: 1.2)
        capture("Paused", in: app)

        resume.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        waitForLabel(app.staticTexts["recordingTimer"], toChangeFrom: pausedTime)
        let save = app.buttons["stopAndSaveButton"]
        XCTAssertFalse(save.isEnabled)
        app.buttons["speakerSetupToggle"].tap()
        let two = app.buttons["speakerCount2"]
        XCTAssertTrue(two.waitForExistence(timeout: 5))
        two.tap()
        app.buttons["speakerRow0"].tap()
        let name = app.textFields["speakerName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Alex\n")
        waitForLabel(app.buttons["speakerRow0"], toEqual: "Alex")
        XCTAssertTrue(save.isEnabled)
        capture("Speaker setup", in: app)
        save.tap()

        XCTAssertTrue(app.buttons["Untitled Recording"].waitForExistence(timeout: 8), app.debugDescription)
        app.terminate()
        let reopened = launch(reset: false)
        let search = reopened.textFields["search"]
        XCTAssertTrue(search.waitForExistence(timeout: 12))
        search.tap()
        search.typeText("Alex\n")
        XCTAssertTrue(reopened.staticTexts["RESULTS"].waitForExistence(timeout: 5))
        reopened.buttons["Untitled Recording"].tap()

        let play = reopened.buttons["playbackButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 8))
        play.tap()
        waitForLabel(play, toEqual: "Pause playback")
        waitForLabel(reopened.staticTexts["playbackTime"], toChangeFrom: "0:00")
        play.tap()
        waitForLabel(play, toEqual: "Play recording")
        capture("Saved recording", in: reopened)
    }

    @MainActor
    func testBackgroundingFinishesTakeAndKeepsItAvailableToSave() {
        let app = launch(reset: true)
        let start = app.buttons["startRecordingButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 15), app.debugDescription)
        waitForLabel(app.staticTexts["recordingTimer"], toChangeFrom: "00:00")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackgroundSuspended, timeout: 5)
            || app.state == .runningBackground)
        app.activate()
        waitForLabel(app.staticTexts["recordingStatus"], toEqual: "STOPPED")
        XCTAssertFalse(app.buttons["pauseButton"].exists)

        app.buttons["speakerSetupToggle"].tap()
        let one = app.buttons["speakerCount1"]
        XCTAssertTrue(one.waitForExistence(timeout: 5))
        one.tap()
        app.buttons["stopAndSaveButton"].tap()
        XCTAssertTrue(app.buttons["Untitled Recording"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testDiscardReturnsToEmptyTimeline() {
        let app = launch(reset: true)
        let start = app.buttons["startRecordingButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 15), app.debugDescription)
        app.buttons["backButton"].tap()
        let cancel = app.buttons["cancelModal"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 5))
        app.buttons["backButton"].tap()
        let discard = app.buttons["discardRecording"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.staticTexts["Ready to record"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Untitled Recording"].exists)
    }

    @MainActor
    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if reset { app.launchArguments.append("--reset-test-archive") }
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, toChangeFrom label: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", label), object: element)
        wait(for: [expectation], timeout: 5)
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, toEqual label: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        wait(for: [expectation], timeout: 5)
    }
}
