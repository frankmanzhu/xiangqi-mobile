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
}
