import Foundation
import XCTest

final class ComparisonTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExactHotRecording() throws {
        guard ProcessInfo.processInfo.environment["VAPOR_HOT_CHECK"] == "1" else {
            throw XCTSkip("Run the dedicated hot-reload check")
        }
        let app = application("Exact")
        XCTAssertNotEqual(app.state, .notRunning)
        XCTAssertNotEqual(app.state, .unknown)
        app.activate()
        activate(button("startRecordingButton", in: app))
        let pause = button("pauseButton", in: app)
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        sleep(2)
        activate(pause)
        let resume = button("resumeButton", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        let timer = app.staticTexts["recordingTimer"]
        let before = timer.label
        XCTAssertNotEqual(before, "00:00")
        print("VAPOR_HOT paused \(Date().timeIntervalSince1970)")
        XCTAssertTrue(app.staticTexts["Paused after edit"].waitForExistence(timeout: 45), app.debugDescription)
        print("VAPOR_HOT presented \(Date().timeIntervalSince1970)")
        XCTAssertEqual(timer.label, before)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Exact hot reload while paused"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        activate(resume)
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        activate(button("speakerSetupToggle", in: app))
        activate(button("speakerCount2", in: app))
        activate(button("stopAndSaveButton", in: app))
        let search = app.textFields["search"]
        XCTAssertTrue(search.waitForExistence(timeout: 12))
        activate(search)
        search.typeText("Hot Speaker\n")
        XCTAssertTrue(button("Updated Recording", in: app).waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Timeline after edit"].exists)
        print("VAPOR_HOT saved \(Date().timeIntervalSince1970)")
        XCTAssertTrue(app.staticTexts["Timeline"].waitForExistence(timeout: 45), app.debugDescription)
    }

    @MainActor
    func testExactRecording() {
        recording("Exact")
    }

    @MainActor
    func testRuneRecording() {
        recording("Rune")
    }

    @MainActor
    func testALaunches() {
        for _ in 0..<5 {
            for framework in ["Exact", "Rune"] {
                let app = application(framework)
                launch(app, framework: framework, measure: true)
                sleep(2)
                mark(framework, "idle-end")
                app.terminate()
            }
        }
    }

    @MainActor
    private func application(_ framework: String) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: framework == "Exact" ? "com.vapor.exact" : "com.vapor.rune-ios")
        if framework == "Rune" {
            app.launchArguments = ["--ui-testing", "--reset-test-archive"]
        }
        return app
    }

    @MainActor
    private func launch(_ app: XCUIApplication, framework: String, measure: Bool = false) {
        let begin = ProcessInfo.processInfo.systemUptime
        app.launch()
        XCTAssertTrue(appears(button("startRecordingButton", in: app), within: 15), app.debugDescription)
        if measure { mark(framework, "idle-start", since: begin) }
    }

    @MainActor
    private func recording(_ framework: String) {
        let app = application(framework)
        launch(app, framework: framework)
        defer { app.terminate() }
        let start = ProcessInfo.processInfo.systemUptime
        activate(button("startRecordingButton", in: app))
        let pause = button("pauseButton", in: app)
        XCTAssertTrue(appears(pause, within: 15), app.debugDescription)
        mark(framework, "capture-start", since: start)
        sleep(4)
        mark(framework, "capture-end")
        activate(pause)
        let resume = button("resumeButton", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 5), app.debugDescription)
        let timer = app.staticTexts["recordingTimer"]
        XCTAssertTrue(timer.exists, app.debugDescription)
        let paused = timer.label
        XCTAssertNotEqual(paused, "00:00")
        let pausedScreenshot = XCTAttachment(screenshot: app.screenshot())
        pausedScreenshot.name = "\(framework) paused recording"
        pausedScreenshot.lifetime = .keepAlways
        add(pausedScreenshot)
        sleep(2)
        XCTAssertEqual(timer.label, paused)
        activate(resume)
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        let expand = ProcessInfo.processInfo.systemUptime
        activate(button("speakerSetupToggle", in: app))
        let two = button("speakerCount2", in: app)
        XCTAssertTrue(appears(two, within: 5), app.debugDescription)
        mark(framework, "expanded", since: expand)
        activate(two)
        activate(button("speakerRow0", in: app))
        let name = app.textFields["speakerName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), app.debugDescription)
        let speaker = "Benchmark Speaker"
        activate(name)
        name.typeText(speaker + "\n")
        XCTAssertTrue(button(speaker, in: app).exists, app.debugDescription)
        let save = button("stopAndSaveButton", in: app)
        XCTAssertTrue(save.isEnabled)
        let saveStart = ProcessInfo.processInfo.systemUptime
        activate(save)
        XCTAssertTrue(appears(app.staticTexts["RECORDINGS"], within: 12), app.debugDescription)
        mark(framework, "saved", since: saveStart)
        let search = app.textFields["search"]
        activate(search)
        search.typeText(speaker + "\n")
        XCTAssertTrue(app.staticTexts["RESULTS"].waitForExistence(timeout: 5), app.debugDescription)
        let session = button("Untitled Recording", in: app)
        XCTAssertTrue(session.exists)
        activate(session)
        let player = button("playbackButton", in: app)
        XCTAssertTrue(player.waitForExistence(timeout: 8), app.debugDescription)
        activate(player)
        let playbackTime = app.staticTexts["playbackTime"]
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "0:00"), object: playbackTime)
        wait(for: [playing], timeout: 8)
        mark(framework, "detail")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(framework) saved recording"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func appears(_ element: XCUIElement, within timeout: TimeInterval) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        repeat {
            if element.exists { return true }
            Thread.sleep(forTimeInterval: 0.025)
        } while ProcessInfo.processInfo.systemUptime < deadline
        return false
    }

    @MainActor
    private func button(_ name: String, in app: XCUIApplication) -> XCUIElement {
        if name.hasPrefix("speakerCount") {
            return app.descendants(matching: .any).matching(identifier: name).firstMatch
        }
        return app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", name, name)).firstMatch
    }

    @MainActor
    private func activate(_ element: XCUIElement) {
        element.tap()
    }

    private func mark(_ framework: String, _ phase: String, since: TimeInterval? = nil) {
        let ms = since.map { (ProcessInfo.processInfo.systemUptime - $0) * 1000 } ?? 0
        print("VAPOR_BENCH \(framework) \(phase) \(Date().timeIntervalSince1970) \(ms)")
    }
}
