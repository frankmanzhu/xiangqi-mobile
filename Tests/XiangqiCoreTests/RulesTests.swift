import XCTest
@testable import XiangqiCore

final class RulesTests: XCTestCase {
    func testStandardPositionRoundTripsAndContainsAllPieces() throws {
        let position = try Position(fen: GameRecord.standardFEN)
        XCTAssertEqual(position.pieces.count, 32)
        XCTAssertEqual(position.sideToMove, .red)
        XCTAssertEqual(position.piece(at: Square(file: 0, rank: 0))?.kind, .chariot)
        XCTAssertEqual(position.piece(at: Square(file: 4, rank: 0))?.kind, .general)
        XCTAssertEqual(position.piece(at: Square(file: 4, rank: 9))?.side, .black)
        XCTAssertEqual(position.fen, GameRecord.standardFEN)
    }

    func testEverySquareAndMoveRoundTripsThroughUCI() {
        for rank in 0...9 {
            for file in 0...8 {
                let square = Square(file: file, rank: rank)
                XCTAssertEqual(Square.parse(square.uci[...]), square)
                let move = Move(from: square, to: Square(file: 8 - file, rank: 9 - rank))
                XCTAssertEqual(Move(uci: move.uci), move)
            }
        }
    }

    func testInitialLegalMovesIncludeRepresentativePieceRules() {
        let position = Position.standard
        let legal = Set(position.legalMoves().map(\.uci))
        XCTAssertTrue(legal.contains("a0a1"), "chariot can move one rank")
        XCTAssertTrue(legal.contains("b0a2"), "horse can move around an open leg")
        XCTAssertTrue(legal.contains("b0c2"))
        XCTAssertTrue(legal.contains("c0a2"), "elephant stays on its side of river")
        XCTAssertTrue(legal.contains("b2b9"), "cannon captures over exactly one screen")
        XCTAssertFalse(legal.contains("a3a2"), "soldier cannot retreat")
        XCTAssertEqual(legal.count, 44)
    }

    func testMoveCannotExposeFlyingGenerals() {
        let redGeneral = Piece(side: .red, kind: .general)
        let blackGeneral = Piece(side: .black, kind: .general)
        let blocker = Piece(side: .red, kind: .chariot)
        let position = Position(
            pieces: [
                Square(file: 4, rank: 0): redGeneral,
                Square(file: 4, rank: 9): blackGeneral,
                Square(file: 4, rank: 5): blocker
            ],
            sideToMove: .red
        )
        let legal = Set(position.legalMoves().map(\.uci))
        XCTAssertFalse(legal.contains("e5d5"))
        XCTAssertTrue(legal.contains("e5e6"))
    }

    func testCommittedSequenceCanBeReplayedFromPortableRecord() throws {
        let moves = ["h2e2", "h7e7", "h0g2"]
        let position = try Position.standard.replaying(moves)
        XCTAssertEqual(position.sideToMove, .black)
        XCTAssertEqual(position.piece(at: Square(file: 6, rank: 2))?.kind, .horse)
        XCTAssertNil(position.piece(at: Square(file: 7, rank: 0)))
    }

    func testPortableRecordUsesOrderedUCIMovesAsPrimaryTruth() throws {
        var record = GameRecord(mode: .localTwoPlayer, humanSide: nil)
        record.moves = [
            RecordedMove(uci: "h2e2", notation: "Cannon h2–e2", side: .red, captured: nil, hintUsed: false)
        ]
        let portable = PortableGame(record: record)
        let data = try portable.encoded()
        let decoded = try JSONDecoder().decode(PortableGame.self, from: data)
        XCTAssertEqual(decoded.format, "xiangqi-uci-json")
        XCTAssertEqual(decoded.moves, ["h2e2"])
        XCTAssertEqual(decoded.startingFEN, GameRecord.standardFEN)
    }
}
