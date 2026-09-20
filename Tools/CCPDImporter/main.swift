import Foundation
import SQLite3
import XiangqiCore

private struct Configuration {
    let datasetRoot: URL
    let outputDirectory: URL
    let sourceRevision: String
    let limit: Int?
    let emitJSONLines: Bool

    init(arguments: [String]) throws {
        guard arguments.count >= 3 else { throw ImporterError.usage }
        datasetRoot = URL(fileURLWithPath: arguments[1], isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()

        var revision = "unknown"
        var parsedLimit: Int?
        var shouldEmitJSONLines = true
        var index = 3
        while index < arguments.count {
            switch arguments[index] {
            case "--source-revision":
                index += 1
                guard index < arguments.count else { throw ImporterError.usage }
                revision = arguments[index]
            case "--limit":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]), value > 0 else {
                    throw ImporterError.usage
                }
                parsedLimit = value
            case "--database-only":
                shouldEmitJSONLines = false
            default:
                throw ImporterError.unknownArgument(arguments[index])
            }
            index += 1
        }
        sourceRevision = revision
        limit = parsedLimit
        emitJSONLines = shouldEmitJSONLines
    }
}

private enum ImporterError: Error, CustomStringConvertible {
    case usage
    case unknownArgument(String)
    case datasetNotFound(String)

    var description: String {
        switch self {
        case .usage:
            "Usage: ccpd-import <Dataset directory> <output directory> [--source-revision SHA] [--limit N] [--database-only]"
        case .unknownArgument(let value):
            "Unknown argument: \(value)"
        case .datasetNotFound(let path):
            "Dataset directory does not exist: \(path)"
        }
    }
}

private struct ImportedRecord: Codable {
    let id: String
    let category: String
    let sourcePath: String
    let sourceEncoding: XiangqiPGNTextEncoding
    let game: NormalizedXiangqiPGNGame
}

private struct QuarantinedRecord: Codable {
    let sourcePath: String
    let category: String
    let reason: String
}

private struct SourceFile {
    let url: URL
    let relativePath: String
    let category: String
}

private struct ImportAudit: Codable {
    let schemaVersion: Int
    let sourceName: String
    let sourceURL: String
    let sourceRevision: String
    let license: String
    let generatedAt: Date
    let discoveredFiles: Int
    let attemptedFiles: Int
    let importedFiles: Int
    let quarantinedFiles: Int
    let categoryDiscoveredCounts: [String: Int]
    let categoryImportedCounts: [String: Int]
    let encodingCounts: [String: Int]
    let quarantineReasonCounts: [String: Int]
}

private final class JSONLinesWriter {
    private let handle: FileHandle
    private let encoder: JSONEncoder

    init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    }

    deinit { try? handle.close() }

    func append<T: Encodable>(_ value: T) throws {
        var data = try encoder.encode(value)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }
}

private final class CCPDDatabaseWriter {
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private var database: OpaquePointer?
    private var insertRecord: OpaquePointer?
    private var insertMetadata: OpaquePointer?
    private let encoder: JSONEncoder

    init(url: URL) throws {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw databaseError("open")
        }
        try execute("PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF; PRAGMA temp_store=MEMORY;")
        try execute("""
            CREATE TABLE metadata (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            );
            CREATE TABLE records (
                id TEXT PRIMARY KEY NOT NULL,
                category TEXT NOT NULL,
                source_path TEXT NOT NULL,
                source_encoding TEXT NOT NULL,
                event TEXT,
                date_text TEXT,
                site TEXT,
                red TEXT,
                black TEXT,
                result TEXT,
                ecco TEXT,
                starting_fen TEXT NOT NULL,
                move_count INTEGER NOT NULL,
                uci_moves TEXT NOT NULL,
                source_moves TEXT NOT NULL,
                tags_json BLOB NOT NULL
            );
            CREATE INDEX records_category_idx ON records(category);
            """)
        try prepare("""
            INSERT INTO records (
                id, category, source_path, source_encoding, event, date_text, site,
                red, black, result, ecco, starting_fen, move_count, uci_moves, source_moves, tags_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, into: &insertRecord)
        try prepare("INSERT INTO metadata (key, value) VALUES (?, ?)", into: &insertMetadata)
        try execute("BEGIN IMMEDIATE TRANSACTION")
    }

    deinit {
        sqlite3_finalize(insertRecord)
        sqlite3_finalize(insertMetadata)
        sqlite3_close(database)
    }

    func append(_ record: ImportedRecord) throws {
        guard let statement = insertRecord else { throw databaseError("insert statement") }
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        try bind(record.id, to: 1, in: statement)
        try bind(record.category, to: 2, in: statement)
        try bind(record.sourcePath, to: 3, in: statement)
        try bind(record.sourceEncoding.rawValue, to: 4, in: statement)
        try bind(record.game.tags["Event"], to: 5, in: statement)
        try bind(record.game.tags["Date"], to: 6, in: statement)
        try bind(record.game.tags["Site"], to: 7, in: statement)
        try bind(record.game.tags["Red"], to: 8, in: statement)
        try bind(record.game.tags["Black"], to: 9, in: statement)
        try bind(record.game.result, to: 10, in: statement)
        try bind(record.game.tags["ECCO"], to: 11, in: statement)
        try bind(record.game.startingFEN, to: 12, in: statement)
        guard sqlite3_bind_int64(statement, 13, Int64(record.game.moves.count)) == SQLITE_OK else {
            throw databaseError("bind move count")
        }
        try bind(CCPDCompression.compress(Data(record.game.moves.map(\.uci).joined().utf8)), to: 14, in: statement)
        let sourceMoves = Data(record.game.moves.map(\.sourceNotation).joined(separator: "\u{001F}").utf8)
        try bind(CCPDCompression.compress(sourceMoves), to: 15, in: statement)
        try bind(CCPDCompression.compress(encoder.encode(record.game.tags)), to: 16, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError("insert record") }
    }

    func finish(metadata: [String: String]) throws {
        guard let statement = insertMetadata else { throw databaseError("metadata statement") }
        for key in metadata.keys.sorted() {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            try bind(key, to: 1, in: statement)
            try bind(metadata[key], to: 2, in: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError("insert metadata") }
        }
        try execute("COMMIT")
        try execute("PRAGMA optimize")
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw databaseError(sql) }
    }

    private func prepare(_ sql: String, into statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("prepare")
        }
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer) throws {
        let result: Int32
        if let value {
            result = value.withCString { sqlite3_bind_text(statement, index, $0, -1, Self.transient) }
        } else {
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else { throw databaseError("bind text") }
    }

    private func bind(_ value: Data, to index: Int32, in statement: OpaquePointer) throws {
        let result = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), Self.transient)
        }
        guard result == SQLITE_OK else { throw databaseError("bind blob") }
    }

    private func databaseError(_ operation: String) -> NSError {
        let message = database.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? "unknown SQLite error"
        return NSError(
            domain: "CCPDImporter.SQLite",
            code: Int(database.map(sqlite3_errcode) ?? SQLITE_ERROR),
            userInfo: [NSLocalizedDescriptionKey: "\(operation): \(message)"]
        )
    }
}

@main
private enum CCPDImporter {
    static func main() throws {
        do {
            let configuration = try Configuration(arguments: CommandLine.arguments)
            try run(configuration)
        } catch {
            FileHandle.standardError.write(Data("ccpd-import: \(error)\n".utf8))
            Foundation.exit(2)
        }
    }

    private static func run(_ configuration: Configuration) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: configuration.datasetRoot.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ImporterError.datasetNotFound(configuration.datasetRoot.path)
        }

        let files = try sourceFiles(in: configuration.datasetRoot)
        let selectedFiles = configuration.limit.map { Array(files.prefix($0)) } ?? files
        try FileManager.default.createDirectory(at: configuration.outputDirectory, withIntermediateDirectories: true)

        let recordsURL = configuration.outputDirectory.appendingPathComponent("ccpd-records.jsonl")
        let quarantineURL = configuration.outputDirectory.appendingPathComponent("ccpd-quarantine.jsonl")
        let auditURL = configuration.outputDirectory.appendingPathComponent("ccpd-audit.json")
        let databaseURL = configuration.outputDirectory.appendingPathComponent("ccpd.sqlite3")
        let recordWriter: JSONLinesWriter?
        if configuration.emitJSONLines {
            recordWriter = try JSONLinesWriter(url: recordsURL)
        } else {
            recordWriter = nil
        }
        let quarantineWriter = try JSONLinesWriter(url: quarantineURL)
        let databaseWriter = try CCPDDatabaseWriter(url: databaseURL)

        var imported = 0
        var quarantined = 0
        var categoryImportedCounts: [String: Int] = [:]
        var encodingCounts: [String: Int] = [:]
        var reasonCounts: [String: Int] = [:]

        for (offset, file) in selectedFiles.enumerated() {
            let sourcePath = file.relativePath
            let category = file.category
            let record: ImportedRecord
            do {
                let decoded = try XiangqiPGNTextDecoder.decode(Data(contentsOf: file.url))
                let parsed = try XiangqiPGNParser.parse(decoded.text)
                let normalized = try XiangqiPGNNormalizer.normalize(parsed)
                record = ImportedRecord(
                    id: stableID(for: sourcePath),
                    category: category,
                    sourcePath: sourcePath,
                    sourceEncoding: decoded.encoding,
                    game: normalized
                )
            } catch {
                let reason = reasonCategory(for: error)
                try quarantineWriter.append(QuarantinedRecord(
                    sourcePath: sourcePath,
                    category: category,
                    reason: String(describing: error)
                ))
                quarantined += 1
                reasonCounts[reason, default: 0] += 1
                continue
            }
            try recordWriter?.append(record)
            try databaseWriter.append(record)
            imported += 1
            categoryImportedCounts[category, default: 0] += 1
            encodingCounts[record.sourceEncoding.rawValue, default: 0] += 1

            if (offset + 1).isMultiple(of: 1_000) {
                print("Processed \(offset + 1)/\(selectedFiles.count); imported \(imported), quarantined \(quarantined)")
            }
        }

        let audit = ImportAudit(
            schemaVersion: 1,
            sourceName: "Chinese Chess Practical Dataset (CCPD)",
            sourceURL: "https://github.com/Yvonne761/Chinese-Chess-Practical-Dataset",
            sourceRevision: configuration.sourceRevision,
            license: "CC BY 4.0",
            generatedAt: Date(),
            discoveredFiles: files.count,
            attemptedFiles: selectedFiles.count,
            importedFiles: imported,
            quarantinedFiles: quarantined,
            categoryDiscoveredCounts: countsByCategory(files),
            categoryImportedCounts: categoryImportedCounts,
            encodingCounts: encodingCounts,
            quarantineReasonCounts: reasonCounts
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(audit).write(to: auditURL, options: .atomic)
        try databaseWriter.finish(metadata: [
            "schema_version": "2",
            "source_name": audit.sourceName,
            "source_url": audit.sourceURL,
            "source_revision": audit.sourceRevision,
            "license": audit.license,
            "imported_files": String(audit.importedFiles),
            "quarantined_files": String(audit.quarantinedFiles)
        ])

        print("Imported \(imported) of \(selectedFiles.count) attempted records; quarantined \(quarantined).")
        print("Audit: \(auditURL.path)")
    }

    private static func sourceFiles(in root: URL) throws -> [SourceFile] {
        try FileManager.default.subpathsOfDirectory(atPath: root.path)
            .filter { URL(fileURLWithPath: $0).pathExtension.lowercased() == "pgn" }
            .sorted()
            .map { relativePath in
                SourceFile(
                    url: root.appendingPathComponent(relativePath),
                    relativePath: relativePath,
                    category: relativePath.split(separator: "/").first.map(String.init) ?? "unknown"
                )
            }
    }

    private static func countsByCategory(_ files: [SourceFile]) -> [String: Int] {
        files.reduce(into: [:]) { counts, file in
            counts[file.category, default: 0] += 1
        }
    }

    private static func stableID(for sourcePath: String) -> String {
        "ccpd:" + sourcePath.dropLast(sourcePath.hasSuffix(".pgn") ? 4 : 0)
    }

    private static func reasonCategory(for error: Error) -> String {
        if let error = error as? XiangqiPGNError {
            return switch error {
            case .unsupportedTextEncoding: "encoding"
            case .malformedTag: "tag"
            case .missingFEN: "missing_fen"
            case .invalidNotation: "notation"
            case .ambiguousNotation: "ambiguous_notation"
            case .illegalMove: "illegal_move"
            }
        }
        if let error = error as? PositionError {
            return switch error {
            case .invalidFEN: "invalid_fen"
            case .invalidMove: "invalid_uci"
            case .illegalMove: "illegal_domain_move"
            }
        }
        return "unexpected"
    }
}
