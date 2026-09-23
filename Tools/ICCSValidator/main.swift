import Foundation
import Dispatch
import XiangqiCore

private struct RawGame: Sendable {
    let tags: [String: String]
    let movetext: [String]
}

private struct ValidGame: Codable, Sendable {
    let source: String
    let sourceIndex: Int
    let tags: [String: String]
    let startingFEN: String
    let sourceMoves: [String]
    let moves: [String]
    let result: String?
    let warnings: [String]
    let canonicalKey: String
}

private struct FailedGame: Codable, Sendable {
    let source: String
    let sourceIndex: Int
    let tags: [String: String]
    let reason: String
    let ply: Int?
    let move: String?
    let positionFEN: String?
    let warnings: [String]
}

private enum ValidationOutcome {
    case valid(ValidGame)
    case failed(FailedGame)
}

private struct Manifest: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let workers: Int
    let sources: [String]
    let discoveredGames: Int
    let replayableGames: Int
    let uniqueGames: Int
    let duplicateGames: Int
    let failedGames: Int
    let warningCounts: [String: Int]
}

private struct Configuration {
    let inputDirectory: URL
    let outputDirectory: URL
    let workers: Int

    init(arguments: [String]) throws {
        guard arguments.count >= 3 else {
            throw ValidationError.usage
        }
        inputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true).standardizedFileURL
        outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true).standardizedFileURL
        var requestedWorkers = ProcessInfo.processInfo.activeProcessorCount
        var index = 3
        while index < arguments.count {
            guard arguments[index] == "--workers", index + 1 < arguments.count,
                  let value = Int(arguments[index + 1]), value > 0 else {
                throw ValidationError.usage
            }
            requestedWorkers = value
            index += 2
        }
        workers = max(1, min(requestedWorkers, 16))
    }
}

private enum ValidationError: Error, CustomStringConvertible {
    case usage
    case missingDirectory(String)
    case invalidText(String)
    case malformedTag(String)

    var description: String {
        switch self {
        case .usage:
            "Usage: iccs-validate <input directory> <output directory> [--workers N]"
        case .missingDirectory(let path):
            "Directory does not exist: \(path)"
        case .invalidText(let path):
            "Input is not UTF-8 text: \(path)"
        case .malformedTag(let line):
            "Malformed tag: \(line)"
        }
    }
}

private enum ICCS {
    static let results: Set<String> = ["1-0", "0-1", "1/2-1/2", "*"]

    static func move(from token: String) -> Move? {
        let characters = Array(token)
        guard characters.count == 5,
              Set("ABCDEFGHI").contains(characters[0]),
              Set("ABCDEFGHI").contains(characters[3]),
              characters[1].isNumber, characters[4].isNumber,
              characters[2] == "-" else { return nil }
        let uci = "\(characters[0].lowercased())\(characters[1])\(characters[3].lowercased())\(characters[4])"
        return Move(uci: uci)
    }
}

private func parseTag(_ line: String) throws -> (String, String)? {
    guard line.first == "[" else { return nil }
    guard line.last == "]" else { throw ValidationError.malformedTag(line) }
    let body = line.dropFirst().dropLast()
    guard let separator = body.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
        throw ValidationError.malformedTag(line)
    }
    let key = String(body[..<separator])
    let value = body[separator...].trimmingCharacters(in: .whitespaces)
    guard value.count >= 2, value.first == "\"", value.last == "\"" else {
        throw ValidationError.malformedTag(line)
    }
    return (key, String(value.dropFirst().dropLast()))
}

private func parseGames(_ data: Data, source: String) throws -> [RawGame] {
    guard let text = String(data: data, encoding: .utf8) else {
        throw ValidationError.invalidText(source)
    }
    var games: [RawGame] = []
    var tags: [String: String] = [:]
    var movetext: [String] = []
    var hasFEN = false

    func flush() {
        guard hasFEN else { return }
        games.append(RawGame(tags: tags, movetext: movetext))
        tags = [:]
        movetext = []
        hasFEN = false
    }

    let lines = text.components(separatedBy: .newlines)
    var lineIndex = 0
    while lineIndex < lines.count {
        var line = lines[lineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        // A few source records wrap long player names across two physical lines.
        // Join a wrapped tag before parsing it, while leaving movetext untouched.
        if line.first == "[", !line.contains("]") {
            while lineIndex + 1 < lines.count, !line.contains("]") {
                lineIndex += 1
                line += " " + lines[lineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if line.isEmpty {
            lineIndex += 1
            continue
        }
        if let tag = try parseTag(line) {
            if tag.0 == "Game", hasFEN { flush() }
            if tag.0 == "FEN", hasFEN { flush() }
            tags[tag.0] = tag.1
            hasFEN = hasFEN || tag.0 == "FEN"
        } else if hasFEN {
            movetext.append(line)
        }
        lineIndex += 1
    }
    flush()
    return games
}

private func countBetween(_ position: Position, _ from: Square, _ to: Square) -> Int {
    guard from.file == to.file || from.rank == to.rank else { return Int.max }
    let dx = (to.file - from.file).signum()
    let dy = (to.rank - from.rank).signum()
    var current = Square(file: from.file + dx, rank: from.rank + dy)
    var count = 0
    while current != to {
        if position.pieces[current] != nil { count += 1 }
        current = Square(file: current.file + dx, rank: current.rank + dy)
    }
    return count
}

private func inPalace(_ square: Square, side: Side) -> Bool {
    (3...5).contains(square.file) && (side == .red ? (0...2).contains(square.rank) : (7...9).contains(square.rank))
}

private func isPseudoLegal(_ position: Position, _ move: Move) -> Bool {
    guard move.from.isValid, move.to.isValid, move.from != move.to,
          let piece = position.pieces[move.from], piece.side == position.sideToMove,
          position.pieces[move.to]?.side != piece.side else { return false }
    let dx = move.to.file - move.from.file
    let dy = move.to.rank - move.from.rank
    let ax = abs(dx)
    let ay = abs(dy)
    switch piece.kind {
    case .general:
        if position.pieces[move.to]?.kind == .general,
           position.pieces[move.to]?.side == piece.side.opponent,
           move.from.file == move.to.file {
            return countBetween(position, move.from, move.to) == 0
        }
        return ax + ay == 1 && inPalace(move.to, side: piece.side)
    case .advisor:
        return ax == 1 && ay == 1 && inPalace(move.to, side: piece.side)
    case .elephant:
        guard ax == 2, ay == 2 else { return false }
        if piece.side == .red && move.to.rank > 4 { return false }
        if piece.side == .black && move.to.rank < 5 { return false }
        return position.pieces[Square(file: move.from.file + dx / 2, rank: move.from.rank + dy / 2)] == nil
    case .horse:
        guard (ax == 1 && ay == 2) || (ax == 2 && ay == 1) else { return false }
        let leg = ax == 2
            ? Square(file: move.from.file + dx.signum(), rank: move.from.rank)
            : Square(file: move.from.file, rank: move.from.rank + dy.signum())
        return position.pieces[leg] == nil
    case .chariot:
        return (dx == 0 || dy == 0) && countBetween(position, move.from, move.to) == 0
    case .cannon:
        guard dx == 0 || dy == 0 else { return false }
        let blockers = countBetween(position, move.from, move.to)
        return position.pieces[move.to] == nil ? blockers == 0 : blockers == 1
    case .soldier:
        if dx == 0 && dy == piece.side.forward { return true }
        let crossedRiver = piece.side == .red ? move.from.rank >= 5 : move.from.rank <= 4
        return crossedRiver && ay == 0 && ax == 1
    }
}

private func replay(_ moves: [Move], from initial: Position) -> (ok: Bool, ply: Int?, position: Position, detail: String?) {
    var position = initial
    for (index, move) in moves.enumerated() {
        guard isPseudoLegal(position, move),
              let next = try? position.applying(move, validate: false),
              !next.isInCheck(position.sideToMove) else {
            return (false, index + 1, position, "illegal move")
        }
        position = next
    }
    return (true, nil, position, nil)
}

private func tokens(from lines: [String]) -> [String] {
    var result: [String] = []
    var braceDepth = 0
    var variationDepth = 0
    for line in lines {
        var visible = ""
        for character in line {
            if braceDepth > 0 {
                if character == "{" { braceDepth += 1 }
                if character == "}" { braceDepth -= 1 }
                continue
            }
            if variationDepth > 0 {
                if character == "(" { variationDepth += 1 }
                if character == ")" { variationDepth -= 1 }
                continue
            }
            if character == "{" { braceDepth = 1 }
            else if character == "(" { variationDepth = 1 }
            else if character == ";" { break }
            else { visible.append(character) }
        }
        result.append(contentsOf: visible.split(whereSeparator: { $0.isWhitespace }).map(String.init))
    }
    return result
}

private func validate(_ game: RawGame, source: String, index: Int) -> ValidationOutcome {
    var warnings: [String] = []
    if game.tags["Game"] == nil { warnings.append("missing_game_tag") }
    if game.tags["Result"] == nil { warnings.append("missing_result") }
    if game.tags["Format"] == nil { warnings.append("missing_format") }
    guard let fen = game.tags["FEN"] else {
        return .failed(FailedGame(source: source, sourceIndex: index, tags: game.tags, reason: "missing_fen", ply: nil, move: nil, positionFEN: nil, warnings: warnings))
    }
    guard let position = try? Position(fen: fen) else {
        return .failed(FailedGame(source: source, sourceIndex: index, tags: game.tags, reason: "invalid_fen", ply: nil, move: nil, positionFEN: fen, warnings: warnings))
    }
    let rawTokens = tokens(from: game.movetext)
    var moves: [Move] = []
    var sourceMoves: [String] = []
    var moveText: [String] = []
    for token in rawTokens {
        if let move = ICCS.move(from: token) {
            moves.append(move)
            sourceMoves.append(token)
            moveText.append(move.uci)
        } else if ICCS.results.contains(token) || token.allSatisfy({ $0 == "." || $0.isNumber }) {
            continue
        } else {
            return .failed(FailedGame(source: source, sourceIndex: index, tags: game.tags, reason: "unknown_token:\(token)", ply: nil, move: nil, positionFEN: fen, warnings: warnings))
        }
    }
    guard !moves.isEmpty else {
        return .failed(FailedGame(source: source, sourceIndex: index, tags: game.tags, reason: "no_moves", ply: nil, move: nil, positionFEN: fen, warnings: warnings))
    }
    let result = replay(moves, from: position)
    guard result.ok else {
        let failedMove = result.ply.map { moveText[$0 - 1] }
        return .failed(FailedGame(source: source, sourceIndex: index, tags: game.tags, reason: result.detail ?? "illegal_move", ply: result.ply, move: failedMove, positionFEN: result.position.fen, warnings: warnings))
    }
    let key = "\(fen)|\(moveText.joined(separator: ","))"
    return .valid(ValidGame(source: source, sourceIndex: index, tags: game.tags, startingFEN: fen, sourceMoves: sourceMoves, moves: moveText, result: game.tags["Result"], warnings: warnings, canonicalKey: key))
}

private func write<T: Encodable>(_ values: [T], to url: URL, encoder: JSONEncoder) throws {
    FileManager.default.createFile(atPath: url.path, contents: nil)
    let output = try FileHandle(forWritingTo: url)
    defer { try? output.close() }
    for value in values {
        var data = try encoder.encode(value)
        data.append(0x0A)
        try output.write(contentsOf: data)
    }
}

private func readLines<T: Decodable>(_ type: T.Type, from url: URL, decoder: JSONDecoder) throws -> [T] {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return try text.split(separator: "\n").map { try decoder.decode(T.self, from: Data($0.utf8)) }
}

@main
private enum ICCSValidator {
    static func main() throws {
        do {
            let configuration = try Configuration(arguments: CommandLine.arguments)
            try run(configuration)
        } catch {
            FileHandle.standardError.write(Data("iccs-validate: \(error)\n".utf8))
            Foundation.exit(2)
        }
    }

    private static func run(_ configuration: Configuration) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: configuration.inputDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ValidationError.missingDirectory(configuration.inputDirectory.path)
        }
        let files = try FileManager.default.subpathsOfDirectory(atPath: configuration.inputDirectory.path)
            .map { configuration.inputDirectory.appendingPathComponent($0) }
            .filter { ["pgn", "pgns"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }
        guard !files.isEmpty else { throw ValidationError.missingDirectory("No .pgn or .pgns files in \(configuration.inputDirectory.path)") }

        var allGames: [(source: String, sourceIndex: Int, game: RawGame)] = []
        for file in files {
            let source = file.path.replacingOccurrences(of: configuration.inputDirectory.path + "/", with: "")
            let parsed = try parseGames(Data(contentsOf: file, options: [.mappedIfSafe]), source: source)
            allGames.append(contentsOf: parsed.enumerated().map { (source, $0.offset + 1, $0.element) })
        }

        let shardRoot = configuration.outputDirectory.appendingPathComponent(".shards", isDirectory: true)
        let processedRoot = configuration.outputDirectory.appendingPathComponent("Processed", isDirectory: true)
        let failedRoot = configuration.outputDirectory.appendingPathComponent("Failed", isDirectory: true)
        let duplicateRoot = configuration.outputDirectory.appendingPathComponent("Duplicates", isDirectory: true)
        for directory in [shardRoot, processedRoot, failedRoot, duplicateRoot] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let gameList = allGames
        let workerCount = min(configuration.workers, max(1, gameList.count))

        DispatchQueue.concurrentPerform(iterations: workerCount) { worker in
            var valid: [ValidGame] = []
            var failed: [FailedGame] = []
            for index in stride(from: worker, to: gameList.count, by: workerCount) {
                let record = gameList[index]
                switch validate(record.game, source: record.source, index: record.sourceIndex) {
                case .valid(let value): valid.append(value)
                case .failed(let value): failed.append(value)
                }
            }
            do {
                try write(valid, to: shardRoot.appendingPathComponent(String(format: "processed-%03d.jsonl", worker)), encoder: encoder)
                try write(failed, to: shardRoot.appendingPathComponent(String(format: "failed-%03d.jsonl", worker)), encoder: encoder)
            } catch {
                fputs("worker \(worker) failed: \(error)\n", stderr)
            }
        }

        let decoder = JSONDecoder()
        var unique: [ValidGame] = []
        var duplicates: [ValidGame] = []
        var failures: [FailedGame] = []
        var seen = Set<String>()
        var warningCounts: [String: Int] = [:]
        for worker in 0..<workerCount {
            let validURL = shardRoot.appendingPathComponent(String(format: "processed-%03d.jsonl", worker))
            let failedURL = shardRoot.appendingPathComponent(String(format: "failed-%03d.jsonl", worker))
            for game in try readLines(ValidGame.self, from: validURL, decoder: decoder) {
                for warning in game.warnings { warningCounts[warning, default: 0] += 1 }
                if seen.insert(game.canonicalKey).inserted { unique.append(game) } else { duplicates.append(game) }
            }
            failures.append(contentsOf: try readLines(FailedGame.self, from: failedURL, decoder: decoder))
        }
        try write(unique, to: processedRoot.appendingPathComponent("unique-games.jsonl"), encoder: encoder)
        try write(duplicates, to: duplicateRoot.appendingPathComponent("duplicate-games.jsonl"), encoder: encoder)
        try write(failures, to: failedRoot.appendingPathComponent("invalid-games.jsonl"), encoder: encoder)

        let manifest = Manifest(schemaVersion: 1, generatedAt: Date(), workers: workerCount, sources: files.map(\.lastPathComponent), discoveredGames: allGames.count, replayableGames: unique.count + duplicates.count, uniqueGames: unique.count, duplicateGames: duplicates.count, failedGames: failures.count, warningCounts: warningCounts)
        let manifestEncoder = JSONEncoder()
        manifestEncoder.dateEncodingStrategy = .iso8601
        manifestEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try manifestEncoder.encode(manifest).write(to: configuration.outputDirectory.appendingPathComponent("manifest.json"), options: .atomic)
        try FileManager.default.removeItem(at: shardRoot)

        print("Discovered games: \(manifest.discoveredGames)")
        print("Replayable games: \(manifest.replayableGames)")
        print("Unique games: \(manifest.uniqueGames)")
        print("Duplicates: \(manifest.duplicateGames)")
        print("Failed: \(manifest.failedGames)")
        print("Output: \(configuration.outputDirectory.path)")
    }
}
