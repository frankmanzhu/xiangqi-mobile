import XCTest
@testable import XiangqiCore

final class ComputerPlayerTests: XCTestCase {
    func testComputerAlwaysReturnsALegalMove() {
        let position = Position.standard
        let legal = Set(position.legalMoves())
        for level in 1...5 {
            let selected = NativeComputerPlayer.chooseMove(
                in: position,
                configuration: ComputerConfiguration(level: level, seed: 42)
            )
            XCTAssertNotNil(selected)
            XCTAssertTrue(legal.contains(selected!))
        }
    }

    func testLowLevelChoiceIsDeterministicForSeed() {
        let configuration = ComputerConfiguration(level: 1, seed: 12345)
        let first = NativeComputerPlayer.chooseMove(in: .standard, configuration: configuration)
        let second = NativeComputerPlayer.chooseMove(in: .standard, configuration: configuration)
        XCTAssertEqual(first, second)
    }
}
