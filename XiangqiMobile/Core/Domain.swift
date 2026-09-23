import Foundation

public enum Side: String, Codable, CaseIterable, Sendable {
    case red
    case black

    public var opponent: Side { self == .red ? .black : .red }
    public var forward: Int { self == .red ? 1 : -1 }

    /// Name used inside the portable game record. Deliberately not localized:
    /// a saved or shared record must read the same in every language.
    public var recordName: String { self == .red ? "Red" : "Black" }
}

public enum PieceKind: String, Codable, CaseIterable, Sendable {
    case general, advisor, elephant, horse, chariot, cannon, soldier

    /// Name used inside the portable game record. Deliberately not localized:
    /// a saved or shared record must read the same in every language.
    public var recordName: String { rawValue.capitalized }
    public var value: Int {
        switch self {
        case .general: 10_000
        case .chariot: 900
        case .cannon: 450
        case .horse: 400
        case .elephant, .advisor: 200
        case .soldier: 100
        }
    }
}

public struct Square: Hashable, Codable, Sendable, Comparable {
    public let file: Int
    public let rank: Int

    public init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    public var isValid: Bool { (0...8).contains(file) && (0...9).contains(rank) }
    public var uci: String {
        guard isValid, let scalar = UnicodeScalar(97 + file) else { return "??" }
        return "\(Character(scalar))\(rank)"
    }

    public static func parse(_ value: Substring) -> Square? {
        guard value.count == 2,
              let first = value.utf8.first,
              let last = value.utf8.last,
              first >= 97, first <= 105,
              last >= 48, last <= 57 else { return nil }
        return Square(file: Int(first - 97), rank: Int(last - 48))
    }

    public static func < (lhs: Square, rhs: Square) -> Bool {
        lhs.rank == rhs.rank ? lhs.file < rhs.file : lhs.rank < rhs.rank
    }
}

public struct Move: Hashable, Codable, Sendable {
    public let from: Square
    public let to: Square

    public init(from: Square, to: Square) {
        self.from = from
        self.to = to
    }

    public var uci: String { from.uci + to.uci }

    public init?(uci: String) {
        guard uci.count == 4 else { return nil }
        let chars = uci[...]
        guard let from = Square.parse(chars.prefix(2)),
              let to = Square.parse(chars.suffix(2)) else { return nil }
        self.init(from: from, to: to)
    }
}

public struct Piece: Hashable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let side: Side
    public let kind: PieceKind

    public init(id: UUID = UUID(), side: Side, kind: PieceKind) {
        self.id = id
        self.side = side
        self.kind = kind
    }
}

public enum GameMode: String, Codable, CaseIterable, Sendable {
    case computer
    case localTwoPlayer

}

public enum TimeControl: String, Codable, CaseIterable, Sendable {
    case casual
    case tenMinutes
    case fifteenMinutes

    public var seconds: Int? {
        switch self {
        case .casual: nil
        case .tenMinutes: 600
        case .fifteenMinutes: 900
        }
    }

}

/// Identifies a theme without enumerating which themes exist.
///
/// An open identifier is what makes the theme set extensible: a build can add
/// or drop a theme without changing this type, and a saved record naming an
/// unknown theme still decodes (the registry substitutes its fallback).
public struct ThemeID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let storageKey = "theme"

    public static let classic = ThemeID("classic")
    public static let tournament = ThemeID("tournament")
    public static let calm = ThemeID("calm")
}

public enum GameResultReason: String, Codable, Sendable {
    case checkmate, stalemate, resignation, timeLoss, repetition
}

public struct GameResult: Codable, Equatable, Sendable {
    public let winner: Side?
    public let reason: GameResultReason

    public init(winner: Side?, reason: GameResultReason) {
        self.winner = winner
        self.reason = reason
    }
}

public struct RecordedMove: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let uci: String
    public let notation: String
    public let side: Side
    public let captured: PieceKind?
    public let hintUsed: Bool
    public let engineSelectionSeed: UInt64?
    public let committedAt: Date

    public init(
        id: UUID = UUID(),
        uci: String,
        notation: String,
        side: Side,
        captured: PieceKind?,
        hintUsed: Bool,
        engineSelectionSeed: UInt64? = nil,
        committedAt: Date = Date()
    ) {
        self.id = id
        self.uci = uci
        self.notation = notation
        self.side = side
        self.captured = captured
        self.hintUsed = hintUsed
        self.engineSelectionSeed = engineSelectionSeed
        self.committedAt = committedAt
    }
}

public struct GameRecord: Codable, Identifiable, Sendable {
    public static let schemaVersion = 1
    public static let standardFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
    public static let rulesPolicyID = "xiangqi-standard-legal@1"

    public let id: UUID
    public let schemaVersion: Int
    public let rulesPolicyID: String
    public let startingFEN: String
    public let mode: GameMode
    public let humanSide: Side?
    public let computerLevel: Int
    public let timeControl: TimeControl
    public let createdAt: Date
    public var moves: [RecordedMove]
    public var result: GameResult?
    public var redSecondsRemaining: Int?
    public var blackSecondsRemaining: Int?
    public var elapsedSeconds: Int
    public var orientation: Side
    public var theme: ThemeID
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        mode: GameMode,
        humanSide: Side?,
        computerLevel: Int = 2,
        timeControl: TimeControl = .casual,
        orientation: Side = .red,
        theme: ThemeID = .classic,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.schemaVersion = Self.schemaVersion
        self.rulesPolicyID = Self.rulesPolicyID
        self.startingFEN = Self.standardFEN
        self.mode = mode
        self.humanSide = humanSide
        self.computerLevel = min(max(computerLevel, 1), 5)
        self.timeControl = timeControl
        self.createdAt = createdAt
        self.moves = []
        self.result = nil
        self.redSecondsRemaining = timeControl.seconds
        self.blackSecondsRemaining = timeControl.seconds
        self.elapsedSeconds = 0
        self.orientation = orientation
        self.theme = theme
        self.updatedAt = createdAt
    }

    public var isActive: Bool { result == nil }
    public var uciMoves: [String] { moves.map(\.uci) }
}
