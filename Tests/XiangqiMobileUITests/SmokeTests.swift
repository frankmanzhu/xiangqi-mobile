import XCTest

final class SmokeTests: XCTestCase {
    private func launchApp(resetGame: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_AU", "-appLanguage", "english"]
        if resetGame { app.launchArguments.append("-resetTestData") }
        app.launch()
        return app
    }

    func testCaptureAppStoreScreenshots() {
        var app = launchApp()
        capture(app, name: "01-home")
        app.buttons["Play Computer"].tap()
        startGame(app)
        XCTAssertTrue(app.otherElements["Xiangqi board"].waitForExistence(timeout: 5))
        app.buttons["Red Soldier, a3, selectable"].tap()
        app.buttons["Empty a4"].tap()
        XCTAssertTrue(app.staticTexts["Your move"].waitForExistence(timeout: 12))
        capture(app, name: "02-game")
        app.terminate()
        app = launchApp()
        app.buttons["Learn and practice"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Mating practice,'")).firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "03-learning-library")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func startGame(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))
        let start = app.buttons["Start game"]
        for _ in 0..<5 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()
    }

    func testPrivacyPolicyIsAvailableInsideSettings() {
        let app = launchApp()
        app.buttons["Settings"].tap()
        let policy = app.buttons["Privacy policy"]
        for _ in 0..<5 where !policy.isHittable { app.swipeUp() }
        XCTAssertTrue(policy.waitForExistence(timeout: 3))
        policy.tap()
        XCTAssertTrue(app.navigationBars["Privacy policy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Data on your device"].exists)
    }

    func testTwoPlayerGameSurvivesRelaunch() {
        let app = launchApp()
        app.buttons["Two Players"].tap()
        startGame(app)
        XCTAssertTrue(app.otherElements["Xiangqi board"].waitForExistence(timeout: 5))
        app.buttons["Red Soldier, a3, selectable"].tap()
        app.buttons["Empty a4"].tap()
        XCTAssertTrue(app.staticTexts["Black to move"].waitForExistence(timeout: 3))
        // Backgrounding waits for the app's save path before termination.
        XCUIDevice.shared.press(.home)
        app.terminate()
        let relaunched = launchApp(resetGame: false)
        let resume = relaunched.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Continue game'")).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(relaunched.staticTexts["Black to move"].waitForExistence(timeout: 5))
        relaunched.buttons["Moves"].tap()
        XCTAssertTrue(relaunched.staticTexts["a3a4"].waitForExistence(timeout: 3))
    }

    func testBundledLearningLibraryOpensPracticeOffline() {
        let app = launchApp()

        app.buttons["Learn and practice"].tap()
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chinese Chess Practical Dataset"].exists)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Mating practice,'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Mating practice"].waitForExistence(timeout: 5))

        let firstRecord = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'ccpd-record-'")
        ).firstMatch
        XCTAssertTrue(firstRecord.waitForExistence(timeout: 5))
        firstRecord.tap()
        XCTAssertTrue(app.otherElements["Practice board"].waitForExistence(timeout: 5))
    }

    func testTwoPlayerGameCanStartAndCommitARecordedMove() {
        let app = launchApp()

        app.buttons["Two Players"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 2))
        startGame(app)

        XCTAssertTrue(app.otherElements["Xiangqi board"].waitForExistence(timeout: 2))
        app.buttons["Red Soldier, a3, selectable"].tap()
        app.buttons["Empty a4"].tap()

        XCTAssertTrue(app.buttons["Moves"].isEnabled)
        XCTAssertTrue(app.staticTexts["Black to move"].exists)

        let board = XCTAttachment(screenshot: app.screenshot())
        board.name = "Board after first move"
        board.lifetime = .keepAlways
        add(board)
    }

    func testComputerGameReceivesARealEngineReply() {
        let app = launchApp()

        app.buttons["Play Computer"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 2))
        startGame(app)

        XCTAssertTrue(app.otherElements["Xiangqi board"].waitForExistence(timeout: 2))
        app.buttons["Red Soldier, a3, selectable"].tap()
        app.buttons["Empty a4"].tap()

        let receivedReply = app.staticTexts["Your move"].waitForExistence(timeout: 12)
        if !receivedReply { print(app.debugDescription) }
        XCTAssertTrue(receivedReply)
        app.buttons["Moves"].tap()
        XCTAssertTrue(app.staticTexts["a3a4"].waitForExistence(timeout: 2))
    }

    func testSuggestedMoveComesFromRealEngineAndRevealsInStages() {
        let app = launchApp()

        app.buttons["Play Computer"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 2))
        startGame(app)
        XCTAssertTrue(app.otherElements["Xiangqi board"].waitForExistence(timeout: 2))

        app.buttons["Red Soldier, a3, selectable"].tap()
        app.buttons["Empty a4"].tap()
        XCTAssertTrue(app.staticTexts["Your move"].waitForExistence(timeout: 12))

        app.buttons["Hint"].tap()
        XCTAssertTrue(app.buttons["Show square"].waitForExistence(timeout: 12))
        app.buttons["Show square"].tap()
        XCTAssertTrue(app.buttons["Hint shown"].waitForExistence(timeout: 2))

        XCTAssertTrue(app.buttons["Empty a3"].exists)
        XCTAssertTrue(app.buttons["Moves"].isEnabled)
    }
}
