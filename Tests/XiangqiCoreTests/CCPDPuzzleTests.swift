import XCTest
@testable import XiangqiCore

final class CCPDPuzzleTests: XCTestCase {
    func testRejectsWrongMoveAndAutomaticallyPlaysRecordedReply() throws {
        let record = fixture(moves: ["b2e2", "b7e7", "b0c2"])
        var puzzle = try CCPDPuzzleSession(record: record)

        let wrong = try XCTUnwrap(Move(uci: "h2e2"))
        XCTAssertEqual(try puzzle.attempt(wrong), .incorrect(expected: Move(uci: "b2e2")!))
        XCTAssertEqual(puzzle.currentPly, 0)
        XCTAssertEqual(puzzle.mistakes, 1)

        let first = try XCTUnwrap(Move(uci: "b2e2"))
        XCTAssertEqual(try puzzle.attempt(first), .correct(reply: Move(uci: "b7e7")))
        XCTAssertEqual(puzzle.currentPly, 2)
        XCTAssertEqual(puzzle.position.sideToMove, .red)
    }

    func testCompletesOddLengthLineAndRestarts() throws {
        let record = fixture(moves: ["b2e2", "b7e7", "b0c2"])
        var puzzle = try CCPDPuzzleSession(record: record)
        _ = try puzzle.attempt(Move(uci: "b2e2")!)
        XCTAssertEqual(try puzzle.attempt(Move(uci: "b0c2")!), .completed)
        XCTAssertTrue(puzzle.isComplete)

        try puzzle.restart()
        XCTAssertFalse(puzzle.isComplete)
        XCTAssertEqual(puzzle.currentPly, 0)
        XCTAssertNil(puzzle.lastMove)
    }

    private func fixture(moves: [String]) -> CCPDRecord {
        let normalized = moves.enumerated().map {
            NormalizedXiangqiPGNMove(ply: $0.offset + 1, sourceNotation: $0.element, uci: $0.element)
        }
        return CCPDRecord(
            summary: CCPDRecordSummary(
                id: "fixture", category: "殺局_殺法_練習題", sourcePath: "fixture.pgn",
                event: nil, dateText: nil, red: nil, black: nil, result: nil, ecco: nil,
                moveCount: normalized.count
            ),
            sourceEncoding: .utf8,
            startingFEN: Position.standard.fen,
            moves: normalized,
            tags: [:]
        )
    }
}
