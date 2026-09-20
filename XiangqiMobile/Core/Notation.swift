import Foundation

public enum MoveNotation {
    public static func display(move: Move, in position: Position) -> String {
        guard let piece = position.piece(at: move.from) else { return move.uci }
        let capture = position.piece(at: move.to) == nil ? "–" : "×"
        return "\(piece.kind.englishName) \(move.from.uci)\(capture)\(move.to.uci)"
    }

    public static func accessibility(move: Move, in position: Position) -> String {
        guard let piece = position.piece(at: move.from) else { return move.uci }
        return "\(piece.side.title) \(piece.kind.englishName) from \(move.from.uci) to \(move.to.uci)"
    }
}

public struct PortableGame: Codable, Sendable {
    public let format: String
    public let schemaVersion: Int
    public let rulesPolicyID: String
    public let startingFEN: String
    public let mode: GameMode
    public let moves: [String]
    public let result: GameResult?

    public init(record: GameRecord) {
        self.format = "xiangqi-uci-json"
        self.schemaVersion = record.schemaVersion
        self.rulesPolicyID = record.rulesPolicyID
        self.startingFEN = record.startingFEN
        self.mode = record.mode
        self.moves = record.uciMoves
        self.result = record.result
    }

    public func encoded(pretty: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try encoder.encode(self)
    }
}
