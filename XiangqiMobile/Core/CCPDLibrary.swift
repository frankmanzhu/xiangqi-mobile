import Foundation
import CoreFoundation
import SQLite3
import zlib

public enum CCPDCompressionError: Error {
    case malformedFrame
    case compressionFailed(Int32)
    case decompressionFailed(Int32)
}

public enum CCPDCompression {
    public static func compress(_ data: Data) throws -> Data {
        guard data.count <= Int(UInt32.max) else { throw CCPDCompressionError.malformedFrame }
        if data.isEmpty { return Data([0, 0, 0, 0]) }
        var compressedLength = uLongf(compressBound(uLong(data.count)))
        var compressed = Data(count: Int(compressedLength))
        let status = compressed.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compress2(
                    destination.bindMemory(to: Bytef.self).baseAddress,
                    &compressedLength,
                    source.bindMemory(to: Bytef.self).baseAddress,
                    uLong(data.count),
                    Z_BEST_SPEED
                )
            }
        }
        guard status == Z_OK else { throw CCPDCompressionError.compressionFailed(status) }
        compressed.count = Int(compressedLength)
        let size = UInt32(data.count)
        var framed = Data([
            UInt8((size >> 24) & 0xff), UInt8((size >> 16) & 0xff),
            UInt8((size >> 8) & 0xff), UInt8(size & 0xff)
        ])
        framed.append(compressed)
        return framed
    }

    public static func decompress(_ data: Data) throws -> Data {
        guard data.count >= 4 else { throw CCPDCompressionError.malformedFrame }
        let size = data.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        if size == 0 { return Data() }
        var outputLength = uLongf(size)
        var output = Data(count: Int(size))
        let payload = data.dropFirst(4)
        let status = output.withUnsafeMutableBytes { destination in
            payload.withUnsafeBytes { source in
                uncompress(
                    destination.bindMemory(to: Bytef.self).baseAddress,
                    &outputLength,
                    source.bindMemory(to: Bytef.self).baseAddress,
                    uLong(payload.count)
                )
            }
        }
        guard status == Z_OK, outputLength == uLongf(size) else {
            throw CCPDCompressionError.decompressionFailed(status)
        }
        return output
    }
}

public enum CCPDLibraryError: Error, CustomStringConvertible {
    case databaseUnavailable(String)
    case unsupportedSchema(String?)
    case corruptRecord(String)

    public var description: String {
        switch self {
        case .databaseUnavailable(let detail): "CCPD library is unavailable: \(detail)"
        case .unsupportedSchema(let version): "Unsupported CCPD library schema: \(version ?? "missing")"
        case .corruptRecord(let detail): "Corrupt CCPD record: \(detail)"
        }
    }
}

public struct CCPDCategorySummary: Equatable, Sendable {
    public let id: String
    public let recordCount: Int

    public init(id: String, recordCount: Int) {
        self.id = id
        self.recordCount = recordCount
    }
}

public struct CCPDRecordSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let category: String
    public let sourcePath: String
    public let event: String?
    public let dateText: String?
    public let red: String?
    public let black: String?
    public let result: String?
    public let ecco: String?
    public let moveCount: Int

    public init(
        id: String,
        category: String,
        sourcePath: String,
        event: String?,
        dateText: String?,
        red: String?,
        black: String?,
        result: String?,
        ecco: String?,
        moveCount: Int
    ) {
        self.id = id
        self.category = category
        self.sourcePath = sourcePath
        self.event = event
        self.dateText = dateText
        self.red = red
        self.black = black
        self.result = result
        self.ecco = ecco
        self.moveCount = moveCount
    }
}

public struct CCPDRecord: Equatable, Sendable {
    public let summary: CCPDRecordSummary
    public let sourceEncoding: XiangqiPGNTextEncoding
    public let startingFEN: String
    public let moves: [NormalizedXiangqiPGNMove]
    public let tags: [String: String]

    public init(
        summary: CCPDRecordSummary,
        sourceEncoding: XiangqiPGNTextEncoding,
        startingFEN: String,
        moves: [NormalizedXiangqiPGNMove],
        tags: [String: String]
    ) {
        self.summary = summary
        self.sourceEncoding = sourceEncoding
        self.startingFEN = startingFEN
        self.moves = moves
        self.tags = tags
    }

    public func position(afterPly ply: Int) throws -> Position {
        let clamped = min(max(ply, 0), moves.count)
        return try Position(fen: startingFEN).replaying(Array(moves.prefix(clamped).map(\.uci)))
    }
}

public struct CCPDLibrary: Sendable {
    public let databaseURL: URL

    public init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    /// Creates the writable database used for user-imported games.
    ///
    /// The app opens both this database and the shipped database through
    /// `CCPDLibrary`, which is intentionally read-only. A future importer can
    /// write records to this file while keeping the bundled seed immutable.
    public static func createEmptyDatabaseIfNeeded(at url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        guard sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nil
        ) == SQLITE_OK, let database else {
            let message = database.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? url.path
            sqlite3_close(database)
            throw CCPDLibraryError.databaseUnavailable(message)
        }
        defer { sqlite3_close(database) }

        let schema = """
            PRAGMA user_version = 2;
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS records (
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
                uci_moves BLOB NOT NULL,
                source_moves BLOB NOT NULL,
                tags_json BLOB NOT NULL
            );
            CREATE INDEX IF NOT EXISTS records_category_idx ON records(category);
            INSERT OR IGNORE INTO metadata (key, value) VALUES ('schema_version', '2');
            INSERT OR IGNORE INTO metadata (key, value) VALUES ('source_name', 'User-imported games');
            INSERT OR IGNORE INTO metadata (key, value) VALUES ('license', 'User-managed records');
            """
        guard sqlite3_exec(database, schema, nil, nil, nil) == SQLITE_OK else {
            throw CCPDLibraryError.databaseUnavailable(String(cString: sqlite3_errmsg(database)))
        }
    }

    public func validate() throws {
        let metadata = try metadata()
        guard metadata["schema_version"] == "2" else {
            throw CCPDLibraryError.unsupportedSchema(metadata["schema_version"])
        }
    }

    public func metadata() throws -> [String: String] {
        try withDatabase { database in
            let statement = try prepare("SELECT key, value FROM metadata ORDER BY key", database: database)
            defer { sqlite3_finalize(statement) }
            var result: [String: String] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                if let key = text(statement, 0), let value = text(statement, 1) { result[key] = value }
            }
            return result
        }
    }

    public func categories() throws -> [CCPDCategorySummary] {
        try withDatabase { database in
            let statement = try prepare(
                "SELECT category, COUNT(*) FROM records GROUP BY category ORDER BY category",
                database: database
            )
            defer { sqlite3_finalize(statement) }
            var result: [CCPDCategorySummary] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = text(statement, 0) else { continue }
                result.append(.init(id: id, recordCount: Int(sqlite3_column_int64(statement, 1))))
            }
            return result
        }
    }

    public func records(
        category: String? = nil,
        matching query: String? = nil,
        sourcePrefix: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) throws -> [CCPDRecordSummary] {
        try withDatabase { database in
            var predicates: [String] = []
            var bindings: [String] = []
            if let category, !category.isEmpty {
                predicates.append("category = ?")
                bindings.append(category)
            }
            if let sourcePrefix, !sourcePrefix.isEmpty {
                predicates.append("source_path LIKE ? ESCAPE '\\'")
                bindings.append("\(escapedLikePattern(sourcePrefix))%")
            }
            if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                let columns = ["event", "red", "black", "ecco", "date_text", "result", "source_path"]
                let variants = chineseSearchVariants(query)
                let clauses = variants.map { _ in
                    "(" + columns.map { "\($0) LIKE ? ESCAPE '\\'" }.joined(separator: " OR ") + ")"
                }
                predicates.append("(" + clauses.joined(separator: " OR ") + ")")
                for variant in variants {
                    let pattern = "%\(escapedLikePattern(variant))%"
                    bindings.append(contentsOf: Array(repeating: pattern, count: columns.count))
                }
            }
            let whereClause = predicates.isEmpty ? "" : " WHERE " + predicates.joined(separator: " AND ")
            let sql = """
                SELECT id, category, source_path, event, date_text, red, black, result, ecco, move_count
                FROM records\(whereClause)
                ORDER BY date_text DESC, source_path ASC
                LIMIT ? OFFSET ?
                """
            let statement = try prepare(sql, database: database)
            defer { sqlite3_finalize(statement) }
            for (index, value) in bindings.enumerated() {
                try bind(value, to: Int32(index + 1), in: statement, database: database)
            }
            sqlite3_bind_int64(statement, Int32(bindings.count + 1), Int64(min(max(limit, 1), 500)))
            sqlite3_bind_int64(statement, Int32(bindings.count + 2), Int64(max(offset, 0)))

            var result: [CCPDRecordSummary] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = text(statement, 0),
                      let category = text(statement, 1),
                      let sourcePath = text(statement, 2) else { continue }
                result.append(.init(
                    id: id,
                    category: category,
                    sourcePath: sourcePath,
                    event: text(statement, 3),
                    dateText: text(statement, 4),
                    red: text(statement, 5),
                    black: text(statement, 6),
                    result: text(statement, 7),
                    ecco: text(statement, 8),
                    moveCount: Int(sqlite3_column_int64(statement, 9))
                ))
            }
            return result
        }
    }

    public func record(id: String) throws -> CCPDRecord? {
        try withDatabase { database in
            let statement = try prepare("""
                SELECT id, category, source_path, event, date_text, red, black, result, ecco,
                       move_count, source_encoding, starting_fen, uci_moves, source_moves, tags_json
                FROM records WHERE id = ? LIMIT 1
                """, database: database)
            defer { sqlite3_finalize(statement) }
            try bind(id, to: 1, in: statement, database: database)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            guard let recordID = text(statement, 0),
                  let category = text(statement, 1),
                  let sourcePath = text(statement, 2),
                  let encodingRaw = text(statement, 10),
                  let encoding = XiangqiPGNTextEncoding(rawValue: encodingRaw),
                  let startingFEN = text(statement, 11),
                  let packedUCIMoves = data(statement, 12),
                  let packedSourceMoves = data(statement, 13),
                  let packedTags = data(statement, 14) else {
                throw CCPDLibraryError.corruptRecord(id)
            }
            let decoder = JSONDecoder()
            let uciMovesData = try CCPDCompression.decompress(packedUCIMoves)
            let sourceMovesData = try CCPDCompression.decompress(packedSourceMoves)
            let tagsData = try CCPDCompression.decompress(packedTags)
            guard let uciMoves = String(data: uciMovesData, encoding: .utf8),
                  let sourceMoves = String(data: sourceMovesData, encoding: .utf8) else {
                throw CCPDLibraryError.corruptRecord("\(id): move data is not UTF-8")
            }
            let uci = try unpackUCIMoves(uciMoves, recordID: id)
            let source = sourceMoves.isEmpty ? [] : sourceMoves.components(separatedBy: "\u{001F}")
            guard uci.count == source.count else {
                throw CCPDLibraryError.corruptRecord("\(id): source/UCI move count mismatch")
            }
            let moves = zip(source, uci).enumerated().map { offset, pair in
                NormalizedXiangqiPGNMove(ply: offset + 1, sourceNotation: pair.0, uci: pair.1)
            }
            let tags = try decoder.decode([String: String].self, from: tagsData)
            let summary = CCPDRecordSummary(
                id: recordID,
                category: category,
                sourcePath: sourcePath,
                event: text(statement, 3),
                dateText: text(statement, 4),
                red: text(statement, 5),
                black: text(statement, 6),
                result: text(statement, 7),
                ecco: text(statement, 8),
                moveCount: Int(sqlite3_column_int64(statement, 9))
            )
            return CCPDRecord(
                summary: summary,
                sourceEncoding: encoding,
                startingFEN: startingFEN,
                moves: moves,
                tags: tags
            )
        }
    }

    private func withDatabase<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            let message = database.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? databaseURL.path
            sqlite3_close(database)
            throw CCPDLibraryError.databaseUnavailable(message)
        }
        defer { sqlite3_close(database) }
        return try operation(database)
    }

    private func prepare(_ sql: String, database: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CCPDLibraryError.databaseUnavailable(String(cString: sqlite3_errmsg(database)))
        }
        return statement
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer, database: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = value.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
        guard result == SQLITE_OK else {
            throw CCPDLibraryError.databaseUnavailable(String(cString: sqlite3_errmsg(database)))
        }
    }

    private func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }

    private func data(_ statement: OpaquePointer, _ column: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, column) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
    }

    private func escapedLikePattern(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private func chineseSearchVariants(_ value: String) -> [String] {
        var result = [value]
        for transform in ["Simplified-Traditional", "Traditional-Simplified"] {
            let mutable = NSMutableString(string: value)
            if CFStringTransform(mutable, nil, transform as CFString, false) {
                let transformed = String(mutable)
                if !result.contains(transformed) { result.append(transformed) }
            }
        }
        return result
    }

    private func unpackUCIMoves(_ packed: String, recordID: String) throws -> [String] {
        guard packed.utf8.count.isMultiple(of: 4), packed.unicodeScalars.allSatisfy(\.isASCII) else {
            throw CCPDLibraryError.corruptRecord("\(recordID): malformed packed UCI moves")
        }
        var moves: [String] = []
        var start = packed.startIndex
        while start < packed.endIndex {
            let end = packed.index(start, offsetBy: 4)
            moves.append(String(packed[start..<end]))
            start = end
        }
        return moves
    }
}

/// Presents the immutable shipped corpus and the user's writable corpus as
/// one learning library. Updates replace only the bundled database; the user
/// database lives in Application Support and is never overwritten by an app
/// update.
public struct LearningLibraryStore: Sendable {
    public let bundled: CCPDLibrary
    public let user: CCPDLibrary

    public init(bundledDatabaseURL: URL, userDatabaseURL: URL) throws {
        try CCPDLibrary.createEmptyDatabaseIfNeeded(at: userDatabaseURL)

        let bundled = CCPDLibrary(databaseURL: bundledDatabaseURL)
        let user = CCPDLibrary(databaseURL: userDatabaseURL)
        try bundled.validate()
        try user.validate()
        self.bundled = bundled
        self.user = user
    }

    public func metadata() throws -> [String: String] {
        var result = try bundled.metadata()
        result["user_database"] = user.databaseURL.lastPathComponent
        result["user_record_count"] = String(try user.categories().reduce(0) { $0 + $1.recordCount })
        return result
    }

    public func categories() throws -> [CCPDCategorySummary] {
        let summaries = try bundled.categories() + user.categories()
        var counts: [String: Int] = [:]
        for summary in summaries {
            counts[summary.id, default: 0] += summary.recordCount
        }
        return counts.keys.sorted().map { .init(id: $0, recordCount: counts[$0] ?? 0) }
    }

    public func records(
        category: String? = nil,
        matching query: String? = nil,
        sourcePrefix: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) throws -> [CCPDRecordSummary] {
        let requestedLimit = min(max(limit, 1), 500)
        let requestedOffset = max(offset, 0)
        let perDatabaseLimit = min(requestedLimit + requestedOffset, 500)
        let combined = try bundled.records(
            category: category,
            matching: query,
            sourcePrefix: sourcePrefix,
            limit: perDatabaseLimit,
            offset: 0
        ) + user.records(
            category: category,
            matching: query,
            sourcePrefix: sourcePrefix,
            limit: perDatabaseLimit,
            offset: 0
        )

        let ordered = combined.sorted { lhs, rhs in
            let lhsDate = lhs.dateText ?? ""
            let rhsDate = rhs.dateText ?? ""
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.sourcePath < rhs.sourcePath
        }
        return Array(ordered.dropFirst(requestedOffset).prefix(requestedLimit))
    }

    public func record(id: String) throws -> CCPDRecord? {
        if id.hasPrefix("user:") { return try user.record(id: id) }
        return try bundled.record(id: id) ?? user.record(id: id)
    }
}
