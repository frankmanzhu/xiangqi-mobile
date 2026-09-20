import Foundation
import CoreFoundation

public enum XiangqiPGNError: Error, Equatable, CustomStringConvertible {
    case unsupportedTextEncoding
    case malformedTag(String)
    case missingFEN
    case invalidNotation(String)
    case ambiguousNotation(String, candidates: [String])
    case illegalMove(ply: Int, notation: String, detail: String)

    public var description: String {
        switch self {
        case .unsupportedTextEncoding:
            "PGN text is neither valid UTF-8 nor Big5."
        case .malformedTag(let line):
            "Malformed PGN tag: \(line)"
        case .missingFEN:
            "PGN does not contain a FEN tag."
        case .invalidNotation(let notation):
            "Unsupported Xiangqi notation: \(notation)"
        case .ambiguousNotation(let notation, let candidates):
            "Ambiguous Xiangqi notation \(notation): \(candidates.joined(separator: ", "))"
        case .illegalMove(let ply, let notation, let detail):
            "Illegal move at ply \(ply), \(notation): \(detail)"
        }
    }
}

public enum XiangqiPGNTextEncoding: String, Codable, Sendable {
    case utf8
    case big5
    case big5HKSCS
}

public struct DecodedXiangqiPGN: Sendable {
    public let text: String
    public let encoding: XiangqiPGNTextEncoding

    public init(text: String, encoding: XiangqiPGNTextEncoding) {
        self.text = text
        self.encoding = encoding
    }
}

public enum XiangqiPGNTextDecoder {
    // Core Foundation's Big5 identifier is stable, but Foundation does not
    // expose a named String.Encoding.big5 constant.
    private static let big5 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0A03))
    )
    private static let big5HKSCS = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0A06))
    )

    public static func decode(_ data: Data) throws -> DecodedXiangqiPGN {
        if let value = String(data: data, encoding: .utf8) {
            return DecodedXiangqiPGN(text: value.removingUTF8BOM, encoding: .utf8)
        }
        if let value = String(data: data, encoding: big5) {
            return DecodedXiangqiPGN(text: value, encoding: .big5)
        }
        if let value = String(data: data, encoding: big5HKSCS) {
            return DecodedXiangqiPGN(text: value, encoding: .big5HKSCS)
        }
        throw XiangqiPGNError.unsupportedTextEncoding
    }
}

public struct XiangqiPGNGame: Equatable, Sendable {
    public let tags: [String: String]
    public let sourceMoves: [String]
    public let comments: [String]
    public let result: String?
    public let rawMovetext: String

    public init(
        tags: [String: String],
        sourceMoves: [String],
        comments: [String],
        result: String?,
        rawMovetext: String
    ) {
        self.tags = tags
        self.sourceMoves = sourceMoves
        self.comments = comments
        self.result = result
        self.rawMovetext = rawMovetext
    }
}

public enum XiangqiPGNParser {
    private static let resultTokens: Set<String> = ["1-0", "0-1", "1/2-1/2", "*"]

    public static func parse(_ text: String) throws -> XiangqiPGNGame {
        var tags: [String: String] = [:]
        var movetextLines: [String] = []
        var inTagSection = true

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if inTagSection, line.hasPrefix("[") {
                let (key, value) = try parseTag(line)
                tags[key] = value
            } else {
                if !line.isEmpty { inTagSection = false }
                movetextLines.append(rawLine)
            }
        }

        let rawMovetext = movetextLines.joined(separator: "\n")
        let scanned = scanMainline(rawMovetext)
        var moves: [String] = []
        var result = tags["Result"]

        for rawToken in scanned.tokens {
            guard let token = moveToken(from: rawToken) else { continue }
            if resultTokens.contains(token) {
                result = token
            } else if !token.hasPrefix("$") {
                moves.append(token)
            }
        }

        return XiangqiPGNGame(
            tags: tags,
            sourceMoves: moves,
            comments: scanned.comments,
            result: result,
            rawMovetext: rawMovetext
        )
    }

    private static func parseTag(_ line: String) throws -> (String, String) {
        guard line.first == "[", line.last == "]" else {
            throw XiangqiPGNError.malformedTag(line)
        }
        let body = line.dropFirst().dropLast()
        guard let separator = body.firstIndex(where: { $0.isWhitespace }) else {
            throw XiangqiPGNError.malformedTag(line)
        }
        let key = String(body[..<separator])
        let remainder = body[separator...].trimmingCharacters(in: .whitespaces)
        guard remainder.count >= 2, remainder.first == "\"", remainder.last == "\"" else {
            throw XiangqiPGNError.malformedTag(line)
        }
        let quoted = remainder.dropFirst().dropLast()
        let value = quoted
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
        return (key, value)
    }

    private static func scanMainline(_ text: String) -> (tokens: [String], comments: [String]) {
        var visible = ""
        var comments: [String] = []
        var comment = ""
        var braceDepth = 0
        var variationDepth = 0
        var semicolonComment = false

        for character in text {
            if semicolonComment {
                if character == "\n" {
                    semicolonComment = false
                    if !comment.isEmpty { comments.append(comment.trimmingCharacters(in: .whitespaces)) }
                    comment = ""
                    visible.append(" ")
                } else {
                    comment.append(character)
                }
                continue
            }
            if braceDepth > 0 {
                if character == "{" { braceDepth += 1 }
                else if character == "}" {
                    braceDepth -= 1
                    if braceDepth == 0 {
                        let value = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty { comments.append(value) }
                        comment = ""
                        visible.append(" ")
                    }
                } else {
                    comment.append(character)
                }
                continue
            }
            if variationDepth > 0 {
                if character == "(" { variationDepth += 1 }
                else if character == ")" { variationDepth -= 1 }
                continue
            }
            switch character {
            case "{": braceDepth = 1
            case "(": variationDepth = 1
            case ";": semicolonComment = true
            default: visible.append(character)
            }
        }

        if !comment.isEmpty {
            comments.append(comment.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return (visible.split(whereSeparator: { $0.isWhitespace }).map(String.init), comments)
    }

    private static func moveToken(from rawToken: String) -> String? {
        var token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty { return nil }

        if let dot = token.firstIndex(of: "."), token[..<dot].allSatisfy(\.isNumber) {
            var suffix = token[token.index(after: dot)...]
            while suffix.first == "." { suffix = suffix.dropFirst() }
            token = String(suffix)
        }
        if token.isEmpty { return nil }

        token = token.trimmingCharacters(in: CharacterSet(charactersIn: "!?+#"))
        return token.isEmpty ? nil : token
    }
}

public struct NormalizedXiangqiPGNMove: Codable, Equatable, Sendable {
    public let ply: Int
    public let sourceNotation: String
    public let uci: String

    public init(ply: Int, sourceNotation: String, uci: String) {
        self.ply = ply
        self.sourceNotation = sourceNotation
        self.uci = uci
    }
}

public struct NormalizedXiangqiPGNGame: Codable, Equatable, Sendable {
    public let tags: [String: String]
    public let startingFEN: String
    public let moves: [NormalizedXiangqiPGNMove]
    public let result: String?

    public init(tags: [String: String], startingFEN: String, moves: [NormalizedXiangqiPGNMove], result: String?) {
        self.tags = tags
        self.startingFEN = startingFEN
        self.moves = moves
        self.result = result
    }
}

public enum XiangqiPGNNormalizer {
    public static func normalize(_ game: XiangqiPGNGame) throws -> NormalizedXiangqiPGNGame {
        guard let startingFEN = game.tags["FEN"] else { throw XiangqiPGNError.missingFEN }
        var position = try Position(fen: startingFEN)
        var normalized: [NormalizedXiangqiPGNMove] = []

        for (index, notation) in game.sourceMoves.enumerated() {
            do {
                let move = try ChineseMoveNotationParser.parse(notation, in: position)
                position = try position.applying(move)
                normalized.append(.init(ply: index + 1, sourceNotation: notation, uci: move.uci))
            } catch let error as XiangqiPGNError {
                throw XiangqiPGNError.illegalMove(
                    ply: index + 1,
                    notation: notation,
                    detail: "\(error.description); position \(position.fen)"
                )
            } catch {
                throw XiangqiPGNError.illegalMove(
                    ply: index + 1,
                    notation: notation,
                    detail: "\(error); position \(position.fen)"
                )
            }
        }

        return NormalizedXiangqiPGNGame(
            tags: game.tags,
            startingFEN: startingFEN,
            moves: normalized,
            result: game.result
        )
    }
}

public enum ChineseMoveNotationParser {
    private enum Direction: Equatable {
        case advance, retreat, horizontal
    }

    private enum RelativePosition {
        case front, middle, back
    }

    public static func parse(_ source: String, in position: Position) throws -> Move {
        let normalized = normalize(source)
        let characters = Array(normalized)
        guard characters.count == 4,
              let direction = direction(for: characters[2]),
              let destination = number(for: characters[3]) else {
            throw XiangqiPGNError.invalidNotation(source)
        }

        let side = position.sideToMove
        let kind: PieceKind
        var candidates: [Square]

        if let directKind = pieceKind(for: characters[0]), let sourceFileNumber = number(for: characters[1]) {
            kind = directKind
            let file = boardFile(forNotationNumber: sourceFileNumber, side: side)
            candidates = position.pieces.compactMap { square, piece in
                piece.side == side && piece.kind == kind && square.file == file ? square : nil
            }
        } else if let relative = relativePosition(for: characters[0]), let relativeKind = pieceKind(for: characters[1]) {
            kind = relativeKind
            let all = position.pieces.compactMap { square, piece in
                piece.side == side && piece.kind == kind ? square : nil
            }
            candidates = relativeCandidates(all, relative: relative, side: side)
        } else {
            throw XiangqiPGNError.invalidNotation(source)
        }

        let legalMoves = position.legalMoves()
        let matches = legalMoves.filter { move in
            candidates.contains(move.from)
                && matches(move, kind: kind, direction: direction, destination: destination, side: side)
        }
        guard matches.count == 1 else {
            if matches.isEmpty { throw XiangqiPGNError.invalidNotation(source) }
            throw XiangqiPGNError.ambiguousNotation(source, candidates: matches.map(\.uci))
        }
        return matches[0]
    }

    private static func normalize(_ source: String) -> String {
        source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "进", with: "進")
            .replacingOccurrences(of: "后", with: "後")
            .replacingOccurrences(of: "车", with: "車")
            .replacingOccurrences(of: "马", with: "馬")
            .replacingOccurrences(of: "帅", with: "帥")
            .replacingOccurrences(of: "将", with: "將")
    }

    private static func pieceKind(for character: Character) -> PieceKind? {
        switch character {
        case "帥", "將": .general
        case "仕", "士": .advisor
        case "相", "象": .elephant
        case "馬", "傌": .horse
        case "車", "俥": .chariot
        case "炮", "砲": .cannon
        case "兵", "卒": .soldier
        default: nil
        }
    }

    private static func direction(for character: Character) -> Direction? {
        switch character {
        case "進": .advance
        case "退": .retreat
        case "平": .horizontal
        default: nil
        }
    }

    private static func relativePosition(for character: Character) -> RelativePosition? {
        switch character {
        case "前": .front
        case "中": .middle
        case "後": .back
        default: nil
        }
    }

    private static func number(for character: Character) -> Int? {
        switch character {
        case "一", "１", "1": 1
        case "二", "２", "2": 2
        case "三", "３", "3": 3
        case "四", "４", "4": 4
        case "五", "５", "5": 5
        case "六", "６", "6": 6
        case "七", "７", "7": 7
        case "八", "８", "8": 8
        case "九", "９", "9": 9
        default: nil
        }
    }

    private static func boardFile(forNotationNumber number: Int, side: Side) -> Int {
        side == .red ? 9 - number : number - 1
    }

    private static func matches(
        _ move: Move,
        kind: PieceKind,
        direction: Direction,
        destination: Int,
        side: Side
    ) -> Bool {
        let rankDelta = move.to.rank - move.from.rank
        switch direction {
        case .horizontal:
            return rankDelta == 0 && boardFile(forNotationNumber: destination, side: side) == move.to.file
        case .advance, .retreat:
            let isAdvance = rankDelta * side.forward > 0
            guard isAdvance == (direction == .advance) else { return false }
            switch kind {
            case .horse, .elephant, .advisor:
                return boardFile(forNotationNumber: destination, side: side) == move.to.file
            case .general, .chariot, .cannon, .soldier:
                return abs(rankDelta) == destination
            }
        }
    }

    private static func relativeCandidates(
        _ squares: [Square],
        relative: RelativePosition,
        side: Side
    ) -> [Square] {
        let groups = Dictionary(grouping: squares, by: \.file).values.filter { $0.count > 1 }
        return groups.compactMap { group in
            let ordered = group.sorted {
                side == .red ? $0.rank > $1.rank : $0.rank < $1.rank
            }
            switch relative {
            case .front: return ordered.first
            case .back: return ordered.last
            case .middle:
                guard ordered.count % 2 == 1 else { return nil }
                return ordered[ordered.count / 2]
            }
        }
    }
}

private extension String {
    var removingUTF8BOM: String {
        first == "\u{FEFF}" ? String(dropFirst()) : self
    }
}
