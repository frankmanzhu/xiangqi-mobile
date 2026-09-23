import CryptoKit
import Foundation
import SQLite3
import XiangqiCore

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

private struct MergeReport: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let baseDatabaseSHA256: String
    let mergedDatabaseSHA256: String
    let baseRecordCount: Int
    let candidateRecordCount: Int
    let inputReplayableRecords: Int
    let skippedExistingDuplicates: Int
    let insertedRecords: Int
    let insertedBySource: [String: Int]
    let categoryCounts: [String: Int]
    let sourceEncodingCounts: [String: Int]
    let storageVerification: StorageVerification
}

private struct StorageVerification: Codable {
    let rowsChecked: Int
    let rowsWithValidPackedMoves: Int
    let sourceAndUCICountsMatch: Int
    let librarySchemaValidated: Bool
}

private struct SourceManifestEntry: Codable {
    let name: String
    let sourceURL: String
    let license: String
    let recordsInserted: Int
    let notes: [String]
}

private struct SourceManifest: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let entries: [String: SourceManifestEntry]
}

private struct VerificationReport: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let candidateDatabaseSHA256: String
    let candidateRecordCount: Int
    let categoryCounts: [String: Int]
    let storageVerification: StorageVerification
}

private struct Configuration {
    let existingDatabase: URL
    let validatedDirectory: URL
    let outputDirectory: URL

    init(arguments: [String]) throws {
        guard arguments.count == 4 else { throw MergerError.usage }
        existingDatabase = URL(fileURLWithPath: arguments[1]).standardizedFileURL
        validatedDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true).standardizedFileURL
        outputDirectory = URL(fileURLWithPath: arguments[3], isDirectory: true).standardizedFileURL
    }
}

private enum MergerError: Error, CustomStringConvertible {
    case usage
    case missingPath(String)
    case database(String)
    case malformedInput(String)

    var description: String {
        switch self {
        case .usage:
            "Usage: ccpd-merge <existing ccpd.sqlite3> <validation directory> <output directory>"
        case .missingPath(let path):
            "Missing path: \(path)"
        case .database(let detail):
            "SQLite error: \(detail)"
        case .malformedInput(let detail):
            "Malformed validation input: \(detail)"
        }
    }
}

private final class JSONLinesReader<Value: Decodable> {
    private let handle: FileHandle
    private let decoder = JSONDecoder()
    private var buffer = Data()
    private var reachedEOF = false

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
    }

    deinit { try? handle.close() }

    func next() throws -> Value? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                if line.isEmpty { continue }
                return try decoder.decode(Value.self, from: line)
            }
            if reachedEOF {
                guard !buffer.isEmpty else { return nil }
                let line = buffer
                buffer.removeAll(keepingCapacity: false)
                return try decoder.decode(Value.self, from: line)
            }
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { reachedEOF = true } else { buffer.append(chunk) }
        }
    }
}

private final class SQLiteDatabase {
    let url: URL
    private(set) var handle: OpaquePointer?

    init(url: URL, flags: Int32) throws {
        self.url = url
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            throw MergerError.database(message)
        }
    }

    deinit { sqlite3_close(handle) }

    var message: String {
        handle.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? url.path
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw MergerError.database(message)
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw MergerError.database(message)
        }
        return statement
    }
}

private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func text(_ statement: OpaquePointer, _ index: Int32) -> String? {
    sqlite3_column_text(statement, index).map { String(cString: $0) }
}

private func blob(_ statement: OpaquePointer, _ index: Int32) -> Data? {
    guard let pointer = sqlite3_column_blob(statement, index) else { return nil }
    return Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, index)))
}

private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer) throws {
    let result: Int32
    if let value {
        result = value.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
    } else {
        result = sqlite3_bind_null(statement, index)
    }
    guard result == SQLITE_OK else { throw MergerError.database("bind text") }
}

private func bind(_ value: Data, to index: Int32, in statement: OpaquePointer) throws {
    let result = value.withUnsafeBytes { bytes in
        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), transient)
    }
    guard result == SQLITE_OK else { throw MergerError.database("bind blob") }
}

private func canonicalKey(fen: String, packedUCI: Data) throws -> String {
    let raw = try CCPDCompression.decompress(packedUCI)
    guard raw.count.isMultiple(of: 4), let value = String(data: raw, encoding: .utf8) else {
        throw MergerError.malformedInput("packed UCI moves")
    }
    var moves: [String] = []
    moves.reserveCapacity(raw.count / 4)
    var index = value.startIndex
    while index < value.endIndex {
        let end = value.index(index, offsetBy: 4)
        moves.append(String(value[index..<end]))
        index = end
    }
    return "\(fen)|\(moves.joined(separator: ","))"
}

private func sha256(of url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
        hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

private func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

private func countRecords(in database: SQLiteDatabase) throws -> Int {
    let statement = try database.prepare("SELECT COUNT(*) FROM records")
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { throw MergerError.database(database.message) }
    return Int(sqlite3_column_int64(statement, 0))
}

private func existingCanonicalKeys(in database: SQLiteDatabase) throws -> Set<String> {
    let statement = try database.prepare("SELECT starting_fen, uci_moves FROM records")
    defer { sqlite3_finalize(statement) }
    var keys = Set<String>()
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let fen = text(statement, 0), let packed = blob(statement, 1) else {
            throw MergerError.malformedInput("existing record has missing move data")
        }
        keys.insert(try canonicalKey(fen: fen, packedUCI: packed))
    }
    return keys
}

private func insert(_ game: ValidGame, into database: SQLiteDatabase) throws {
    let statement = try database.prepare("""
        INSERT INTO records (
            id, category, source_path, source_encoding, event, date_text, site,
            red, black, result, ecco, starting_fen, move_count, uci_moves,
            source_moves, tags_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """)
    defer { sqlite3_finalize(statement) }

    var tags = game.tags
    let sourceDataset = game.source.lowercased().hasPrefix("wxf") ? "WXF" : "Dongping"
    tags["SourceDataset"] = sourceDataset
    tags["SourceNotation"] = "ICCS"
    tags["OriginalSource"] = game.source

    try bind("iccs:\(sourceDataset.lowercased()):\(game.sourceIndex)", to: 1, in: statement)
    try bind("對局", to: 2, in: statement)
    try bind("ICCS/\(sourceDataset)/\(game.source)/\(String(format: "%06d", game.sourceIndex)).pgn", to: 3, in: statement)
    try bind(XiangqiPGNTextEncoding.utf8.rawValue, to: 4, in: statement)
    try bind(tags["Event"], to: 5, in: statement)
    try bind(tags["Date"], to: 6, in: statement)
    try bind(tags["Site"], to: 7, in: statement)
    try bind(tags["Red"], to: 8, in: statement)
    try bind(tags["Black"], to: 9, in: statement)
    try bind(game.result, to: 10, in: statement)
    try bind(nil, to: 11, in: statement)
    try bind(game.startingFEN, to: 12, in: statement)
    guard sqlite3_bind_int64(statement, 13, Int64(game.moves.count)) == SQLITE_OK else {
        throw MergerError.database("bind move count")
    }
    try bind(try CCPDCompression.compress(Data(game.moves.joined().utf8)), to: 14, in: statement)
    try bind(try CCPDCompression.compress(Data(game.sourceMoves.joined(separator: "\u{001F}").utf8)), to: 15, in: statement)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    try bind(try CCPDCompression.compress(encoder.encode(tags)), to: 16, in: statement)
    guard sqlite3_step(statement) == SQLITE_DONE else { throw MergerError.database(database.message) }
}

private func verifyStorage(in database: SQLiteDatabase, expectedInsertedIDs: Set<String>) throws -> StorageVerification {
    let statement = try database.prepare("SELECT id, starting_fen, move_count, uci_moves, source_moves FROM records WHERE id LIKE 'iccs:%'")
    defer { sqlite3_finalize(statement) }
    var rows = 0
    var packedOK = 0
    var countsMatch = 0
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let id = text(statement, 0), expectedInsertedIDs.contains(id),
              let fen = text(statement, 1), let packedUCI = blob(statement, 3),
              let packedSource = blob(statement, 4) else {
            throw MergerError.malformedInput("merged ICCS row")
        }
        _ = try canonicalKey(fen: fen, packedUCI: packedUCI)
        let uci = try CCPDCompression.decompress(packedUCI)
        let source = try CCPDCompression.decompress(packedSource)
        guard uci.count.isMultiple(of: 4),
              source.isEmpty == uci.isEmpty || source.split(separator: 0x1F).count == uci.count / 4 else {
            throw MergerError.malformedInput("move/source count mismatch for \(id)")
        }
        rows += 1
        packedOK += 1
        if Int(sqlite3_column_int64(statement, 2)) == uci.count / 4 { countsMatch += 1 }
    }
    guard rows == expectedInsertedIDs.count else {
        throw MergerError.malformedInput("expected \(expectedInsertedIDs.count) inserted rows, found \(rows)")
    }
    return StorageVerification(rowsChecked: rows, rowsWithValidPackedMoves: packedOK, sourceAndUCICountsMatch: countsMatch, librarySchemaValidated: false)
}

@main
private enum CCPDMerger {
    static func main() throws {
        do {
            let configuration = try Configuration(arguments: CommandLine.arguments)
            try run(configuration)
        } catch {
            FileHandle.standardError.write(Data("ccpd-merge: \(error)\n".utf8))
            Foundation.exit(2)
        }
    }

    private static func run(_ configuration: Configuration) throws {
        guard FileManager.default.fileExists(atPath: configuration.existingDatabase.path) else {
            throw MergerError.missingPath(configuration.existingDatabase.path)
        }
        let validationFile = configuration.validatedDirectory.appendingPathComponent("Processed/unique-games.jsonl")
        guard FileManager.default.fileExists(atPath: validationFile.path) else {
            throw MergerError.missingPath(validationFile.path)
        }

        let fileManager = FileManager.default
        let backupDirectory = configuration.outputDirectory.appendingPathComponent("Backup", isDirectory: true)
        try ensureDirectory(backupDirectory)
        try ensureDirectory(configuration.outputDirectory)
        let backupURL = backupDirectory.appendingPathComponent("ccpd.sqlite3")
        if !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: configuration.existingDatabase, to: backupURL)
        }
        let baseHash = try sha256(of: backupURL)
        try Data("\(baseHash)  ccpd.sqlite3\n".utf8).write(to: backupDirectory.appendingPathComponent("backup-sha256.txt"), options: .atomic)

        let candidateURL = configuration.outputDirectory.appendingPathComponent("ccpd.sqlite3")
        if fileManager.fileExists(atPath: candidateURL.path) { try fileManager.removeItem(at: candidateURL) }
        try fileManager.copyItem(at: backupURL, to: candidateURL)

        let readDatabase = try SQLiteDatabase(url: backupURL, flags: SQLITE_OPEN_READONLY)
        let baseCount = try countRecords(in: readDatabase)
        var existingKeys = try existingCanonicalKeys(in: readDatabase)
        let database = try SQLiteDatabase(url: candidateURL, flags: SQLITE_OPEN_READWRITE)
        try database.execute("BEGIN IMMEDIATE TRANSACTION")

        var inputCount = 0
        var skipped = 0
        var inserted = 0
        var insertedBySource: [String: Int] = [:]
        var insertedIDs = Set<String>()
        let reader = try JSONLinesReader<ValidGame>(url: validationFile)
        do {
            while let game = try reader.next() {
                inputCount += 1
                if existingKeys.contains(game.canonicalKey) {
                    skipped += 1
                    continue
                }
                try insert(game, into: database)
                existingKeys.insert(game.canonicalKey)
                let dataset = game.source.lowercased().hasPrefix("wxf") ? "WXF" : "Dongping"
                insertedBySource[dataset, default: 0] += 1
                insertedIDs.insert("iccs:\(dataset.lowercased()):\(game.sourceIndex)")
                inserted += 1
                if inserted.isMultiple(of: 10_000) { print("Inserted \(inserted) records") }
            }
            try database.execute("""
                INSERT OR REPLACE INTO metadata (key, value) VALUES
                ('source_name', 'CCPD + validated ICCS match collections'),
                ('license', 'Mixed sources; see source manifests'),
                ('imported_files', '\(baseCount + inserted)'),
                ('merged_base_records', '\(baseCount)'),
                ('merged_new_records', '\(inserted)'),
                ('merged_skipped_duplicates', '\(skipped)'),
                ('merged_sources', 'CCPD; WXF mirror; Dongping mirror'),
                ('merge_base_sha256', '\(baseHash)')
                """)
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        var storage = try verifyStorage(in: database, expectedInsertedIDs: insertedIDs)
        let library = CCPDLibrary(databaseURL: candidateURL)
        try library.validate()
        storage = StorageVerification(rowsChecked: storage.rowsChecked, rowsWithValidPackedMoves: storage.rowsWithValidPackedMoves, sourceAndUCICountsMatch: storage.sourceAndUCICountsMatch, librarySchemaValidated: true)
        let candidateCount = try countRecords(in: database)
        let categories = try library.categories().reduce(into: [String: Int]()) { $0[$1.id] = $1.recordCount }
        let encodings = try databaseEncodings(database)
        let candidateHash = try sha256(of: candidateURL)
        let report = MergeReport(schemaVersion: 1, generatedAt: Date(), baseDatabaseSHA256: baseHash, mergedDatabaseSHA256: candidateHash, baseRecordCount: baseCount, candidateRecordCount: candidateCount, inputReplayableRecords: inputCount, skippedExistingDuplicates: skipped, insertedRecords: inserted, insertedBySource: insertedBySource, categoryCounts: categories, sourceEncodingCounts: encodings, storageVerification: storage)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: configuration.outputDirectory.appendingPathComponent("merge-report.json"), options: .atomic)
        let sourceManifest = SourceManifest(
            schemaVersion: 1,
            generatedAt: Date(),
            entries: [
                "ccpd": SourceManifestEntry(
                    name: "Chinese Chess Practical Dataset (CCPD)",
                    sourceURL: "https://github.com/Yvonne761/Chinese-Chess-Practical-Dataset",
                    license: "CC BY 4.0",
                    recordsInserted: baseCount,
                    notes: ["Pinned revision 368a47a947773dd8692c026e286dd19b6277b993", "Existing records retained from the verified bundled database"]
                ),
                "wxf": SourceManifestEntry(
                    name: "WXF ICCS games (unverified mirror)",
                    sourceURL: "https://github.com/CGLemon/chinese-chess-PGN",
                    license: "Unknown; no explicit redistribution license recorded",
                    recordsInserted: insertedBySource["WXF"] ?? 0,
                    notes: ["Filename and game count match the WXF collection described by the reference README", "Local download metadata contains no original URL", "Records were replay-validated, deduplicated, and transformed for offline learning; the source license was not independently recorded"]
                ),
                "dongping": SourceManifestEntry(
                    name: "Dongping ICCS games (unverified mirror)",
                    sourceURL: "https://github.com/CGLemon/chinese-chess-PGN",
                    license: "Unknown; no explicit redistribution license recorded",
                    recordsInserted: insertedBySource["Dongping"] ?? 0,
                    notes: ["Filename and game count match the Dongping collection described by the reference README", "Local download metadata contains no original URL", "Records were replay-validated, deduplicated, and transformed for offline learning; the source license was not independently recorded"]
                )
            ]
        )
        try encoder.encode(sourceManifest).write(to: configuration.outputDirectory.appendingPathComponent("source-manifest.json"), options: .atomic)
        let verification = VerificationReport(
            schemaVersion: 1,
            generatedAt: Date(),
            candidateDatabaseSHA256: candidateHash,
            candidateRecordCount: candidateCount,
            categoryCounts: categories,
            storageVerification: storage
        )
        try encoder.encode(verification).write(to: configuration.outputDirectory.appendingPathComponent("verification-report.json"), options: .atomic)
        try Data("\(candidateHash)  ccpd.sqlite3\n".utf8).write(to: configuration.outputDirectory.appendingPathComponent("merged-sha256.txt"), options: .atomic)
        print("Base records: \(baseCount)")
        print("Validated input records: \(inputCount)")
        print("Skipped existing duplicates: \(skipped)")
        print("Inserted records: \(inserted)")
        print("Candidate records: \(candidateCount)")
        print("Candidate database: \(candidateURL.path)")
    }

    private static func databaseEncodings(_ database: SQLiteDatabase) throws -> [String: Int] {
        let statement = try database.prepare("SELECT source_encoding, COUNT(*) FROM records GROUP BY source_encoding")
        defer { sqlite3_finalize(statement) }
        var result: [String: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            if let encoding = text(statement, 0) { result[encoding] = Int(sqlite3_column_int64(statement, 1)) }
        }
        return result
    }
}
