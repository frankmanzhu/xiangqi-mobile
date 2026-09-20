import Foundation

public enum CCPDPuzzleAttempt: Equatable, Sendable {
    case incorrect(expected: Move)
    case correct(reply: Move?)
    case completed
}

/// A deterministic practice session built from a validated CCPD main line.
/// The learner plays the starting side and the recorded reply is applied
/// automatically, keeping practice faithful to the source record.
public struct CCPDPuzzleSession: Equatable, Sendable {
    public let recordID: String
    public let practiceSide: Side
    public private(set) var position: Position
    public private(set) var currentPly: Int
    public private(set) var lastMove: Move?
    public private(set) var mistakes: Int

    private let startingFEN: String
    private let line: [Move]

    public init(record: CCPDRecord) throws {
        let startingPosition = try Position(fen: record.startingFEN)
        let moves = try record.moves.map { normalized -> Move in
            guard let move = Move(uci: normalized.uci) else {
                throw CCPDLibraryError.corruptRecord("\(record.summary.id): malformed move \(normalized.uci)")
            }
            return move
        }
        self.recordID = record.summary.id
        self.practiceSide = startingPosition.sideToMove
        self.position = startingPosition
        self.currentPly = 0
        self.lastMove = nil
        self.mistakes = 0
        self.startingFEN = record.startingFEN
        self.line = moves
    }

    public var expectedMove: Move? {
        currentPly < line.count ? line[currentPly] : nil
    }

    public var isComplete: Bool { currentPly >= line.count }

    @discardableResult
    public mutating func attempt(_ move: Move) throws -> CCPDPuzzleAttempt {
        guard let expectedMove else { return .completed }
        guard move == expectedMove else {
            mistakes += 1
            return .incorrect(expected: expectedMove)
        }

        position = try position.applying(move)
        currentPly += 1
        lastMove = move
        guard currentPly < line.count else { return .completed }

        let reply = line[currentPly]
        position = try position.applying(reply)
        currentPly += 1
        lastMove = reply
        return currentPly >= line.count ? .completed : .correct(reply: reply)
    }

    public mutating func restart() throws {
        position = try Position(fen: startingFEN)
        currentPly = 0
        lastMove = nil
        mistakes = 0
    }
}
