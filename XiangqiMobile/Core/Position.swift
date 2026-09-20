import Foundation

public enum PositionError: Error, Equatable, CustomStringConvertible {
    case invalidFEN(String)
    case invalidMove(String)
    case illegalMove(String)

    public var description: String {
        switch self {
        case .invalidFEN(let detail): "Invalid FEN: \(detail)"
        case .invalidMove(let move): "Invalid move: \(move)"
        case .illegalMove(let move): "Illegal move: \(move)"
        }
    }
}

public struct Position: Equatable, Sendable {
    public private(set) var pieces: [Square: Piece]
    public private(set) var sideToMove: Side
    public private(set) var halfmoveClock: Int
    public private(set) var fullmoveNumber: Int

    public init(
        pieces: [Square: Piece],
        sideToMove: Side,
        halfmoveClock: Int = 0,
        fullmoveNumber: Int = 1
    ) {
        self.pieces = pieces
        self.sideToMove = sideToMove
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    public init(fen: String) throws {
        let fields = fen.split(separator: " ")
        guard fields.count >= 2 else { throw PositionError.invalidFEN("missing fields") }
        let rows = fields[0].split(separator: "/", omittingEmptySubsequences: false)
        guard rows.count == 10 else { throw PositionError.invalidFEN("expected 10 ranks") }

        var parsed: [Square: Piece] = [:]
        for (rowIndex, row) in rows.enumerated() {
            var file = 0
            let rank = 9 - rowIndex
            for character in row {
                if let emptyCount = character.wholeNumberValue {
                    file += emptyCount
                    continue
                }
                guard file < 9, let identity = Self.identity(for: character) else {
                    throw PositionError.invalidFEN("unknown piece or rank overflow")
                }
                parsed[Square(file: file, rank: rank)] = Piece(side: identity.0, kind: identity.1)
                file += 1
            }
            guard file == 9 else { throw PositionError.invalidFEN("rank \(rank) has \(file) files") }
        }
        guard fields[1] == "w" || fields[1] == "b" else {
            throw PositionError.invalidFEN("side to move")
        }
        let generals = parsed.values.filter { $0.kind == .general }
        guard generals.filter({ $0.side == .red }).count == 1,
              generals.filter({ $0.side == .black }).count == 1 else {
            throw PositionError.invalidFEN("expected one general per side")
        }
        self.pieces = parsed
        self.sideToMove = fields[1] == "w" ? .red : .black
        self.halfmoveClock = fields.count > 4 ? Int(fields[4]) ?? 0 : 0
        self.fullmoveNumber = fields.count > 5 ? Int(fields[5]) ?? 1 : 1
    }

    public static var standard: Position { try! Position(fen: GameRecord.standardFEN) }

    public var fen: String {
        var rows: [String] = []
        for rank in stride(from: 9, through: 0, by: -1) {
            var row = ""
            var empty = 0
            for file in 0...8 {
                if let piece = pieces[Square(file: file, rank: rank)] {
                    if empty > 0 { row += String(empty); empty = 0 }
                    row.append(Self.fenCharacter(for: piece))
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += String(empty) }
            rows.append(row)
        }
        return "\(rows.joined(separator: "/")) \(sideToMove == .red ? "w" : "b") - - \(halfmoveClock) \(fullmoveNumber)"
    }

    public func piece(at square: Square) -> Piece? { pieces[square] }

    public func applying(_ move: Move, validate: Bool = true) throws -> Position {
        guard move.from.isValid, move.to.isValid, let moving = pieces[move.from] else {
            throw PositionError.invalidMove(move.uci)
        }
        if validate && !legalMoves().contains(move) {
            throw PositionError.illegalMove(move.uci)
        }
        var next = self
        let captured = next.pieces.removeValue(forKey: move.to)
        next.pieces.removeValue(forKey: move.from)
        next.pieces[move.to] = moving
        next.sideToMove = sideToMove.opponent
        next.halfmoveClock = (captured != nil || moving.kind == .soldier) ? 0 : halfmoveClock + 1
        if sideToMove == .black { next.fullmoveNumber += 1 }
        return next
    }

    public func replaying(_ moves: [String]) throws -> Position {
        var position = self
        for uci in moves {
            guard let move = Move(uci: uci) else { throw PositionError.invalidMove(uci) }
            position = try position.applying(move)
        }
        return position
    }

    private static func identity(for character: Character) -> (Side, PieceKind)? {
        let side: Side = character.isUppercase ? .red : .black
        let kind: PieceKind?
        switch character.lowercased() {
        case "k": kind = .general
        case "a": kind = .advisor
        case "b": kind = .elephant
        case "n", "h": kind = .horse
        case "r": kind = .chariot
        case "c": kind = .cannon
        case "p": kind = .soldier
        default: kind = nil
        }
        return kind.map { (side, $0) }
    }

    private static func fenCharacter(for piece: Piece) -> Character {
        let value: Character
        switch piece.kind {
        case .general: value = "k"
        case .advisor: value = "a"
        case .elephant: value = "b"
        case .horse: value = "n"
        case .chariot: value = "r"
        case .cannon: value = "c"
        case .soldier: value = "p"
        }
        return piece.side == .red ? Character(value.uppercased()) : value
    }
}
