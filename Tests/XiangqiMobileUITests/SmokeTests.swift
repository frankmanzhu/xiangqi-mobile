import XCTest

final class SmokeTests: XCTestCase {
    func testTwoPlayerGameCanStartAndCommitARecordedMove() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetTestData"]
        app.launch()

        app.buttons["Two players"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 2))
        app.buttons["Start game"].tap()

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
        let app = XCUIApplication()
        app.launchArguments = ["-resetTestData"]
        app.launch()

        app.buttons["Play computer"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 2))
        app.buttons["Start game"].tap()

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
        let app = XCUIApplication()
        app.launchArguments = ["-resetTestData"]
        app.launch()

        app.buttons["Play computer"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 2))
        app.buttons["Start game"].tap()
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
