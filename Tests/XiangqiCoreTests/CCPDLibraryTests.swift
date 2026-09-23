import Foundation
import SQLite3
import XCTest
@testable import XiangqiCore

final class CCPDLibraryTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCPDLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        databaseURL = temporaryDirectory.appendingPathComponent("fixture.sqlite3")
        try createFixtureDatabase(at: databaseURL)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testValidatesMetadataAndListsCategories() throws {
        let library = CCPDLibrary(databaseURL: databaseURL)
        XCTAssertNoThrow(try library.validate())
        XCTAssertEqual(try library.metadata()["source_revision"], "fixture-revision")
        XCTAssertEqual(try library.categories(), [.init(id: "開局", recordCount: 1)])
    }

    func testSearchesMetadataAndLoadsReplayableRecord() throws {
        let library = CCPDLibrary(databaseURL: databaseURL)
        let summaries = try library.records(category: "開局", matching: "測試")
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].red, "劉憶慈")
        XCTAssertEqual(summaries[0].moveCount, 1)

        let record = try XCTUnwrap(library.record(id: "ccpd:開局/fixture"))
        XCTAssertEqual(record.moves.map(\.uci), ["h2e2"])
        XCTAssertEqual(record.tags["Event"], "測試對局")
        XCTAssertEqual(try record.position(afterPly: 1).piece(at: Square(file: 4, rank: 2))?.kind, .cannon)

        XCTAssertEqual(try library.records(matching: "刘忆慈").map(\.id), ["ccpd:開局/fixture"])
        XCTAssertEqual(try library.records(matching: "2026").map(\.id), ["ccpd:開局/fixture"])
        XCTAssertEqual(try library.records(matching: "*").map(\.id), ["ccpd:開局/fixture"])
    }

    func testReturnsNilForUnknownRecord() throws {
        XCTAssertNil(try CCPDLibrary(databaseURL: databaseURL).record(id: "missing"))
    }

    func testLearningStoreCreatesSeparateUserDatabaseAndCombinesLibraries() throws {
        let userURL = temporaryDirectory.appendingPathComponent("user-games.sqlite3")
        let store = try LearningLibraryStore(
            bundledDatabaseURL: databaseURL,
            userDatabaseURL: userURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: userURL.path))
        XCTAssertEqual(try store.categories(), [.init(id: "開局", recordCount: 1)])
        XCTAssertEqual(try store.records(category: "開局", matching: "測試").map(\.id), ["ccpd:開局/fixture"])
        XCTAssertEqual(try store.record(id: "ccpd:開局/fixture")?.summary.id, "ccpd:開局/fixture")
    }

    func testCompressedPayloadRoundTripsUnicodeAndEmptyData() throws {
        for original in [Data(), Data("炮二平五\u{001F}馬８進７".utf8)] {
            XCTAssertEqual(try CCPDCompression.decompress(CCPDCompression.compress(original)), original)
        }
    }

    func testBundledCorpusMetadataSearchAndReplay() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot.appendingPathComponent("Resources/Learning/ccpd.sqlite3")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Bundled CCPD database is not present")
        }

        let library = CCPDLibrary(databaseURL: url)
        try library.validate()
        XCTAssertEqual(try library.metadata()["source_revision"], "368a47a947773dd8692c026e286dd19b6277b993")
        XCTAssertEqual(try library.categories().reduce(0) { $0 + $1.recordCount }, 145_065)
        XCTAssertFalse(try library.records(matching: "刘").isEmpty)

        let summary = try XCTUnwrap(library.records(category: "殺局_殺法_練習題", limit: 1).first)
        let record = try XCTUnwrap(library.record(id: summary.id))
        XCTAssertEqual(record.moves.count, summary.moveCount)
        XCTAssertNoThrow(try record.position(afterPly: record.moves.count))
    }

    private func createFixtureDatabase(at url: URL) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else { return XCTFail("Could not create fixture database") }
        defer { sqlite3_close(database) }

        let schema = """
            CREATE TABLE metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
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
            INSERT INTO metadata VALUES ('schema_version', '2');
            INSERT INTO metadata VALUES ('source_revision', 'fixture-revision');
            """
        XCTAssertEqual(sqlite3_exec(database, schema, nil, nil, nil), SQLITE_OK)

        let sql = """
            INSERT INTO records (
                id, category, source_path, source_encoding, event, date_text, site,
                red, black, result, ecco, starting_fen, move_count, uci_moves, source_moves, tags_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
        guard let statement else { return XCTFail("Could not prepare fixture insert") }
        defer { sqlite3_finalize(statement) }

        let values: [String?] = [
            "ccpd:開局/fixture", "開局", "開局/fixture.pgn", "big5", "測試對局",
            "2026", "悉尼", "劉憶慈", "黑方", "*", "C00", GameRecord.standardFEN
        ]
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in values.enumerated() {
            if let value {
                _ = value.withCString { sqlite3_bind_text(statement, Int32(offset + 1), $0, -1, transient) }
            } else {
                sqlite3_bind_null(statement, Int32(offset + 1))
            }
        }
        sqlite3_bind_int64(statement, 13, 1)
        let tags = try JSONEncoder().encode(["Event": "測試對局", "Red": "劉憶慈", "Black": "黑方"])
        let uciMoves = try CCPDCompression.compress(Data("h2e2".utf8))
        let sourceMoves = try CCPDCompression.compress(Data("炮二平五".utf8))
        let packedTags = try CCPDCompression.compress(tags)
        _ = uciMoves.withUnsafeBytes { sqlite3_bind_blob(statement, 14, $0.baseAddress, Int32($0.count), transient) }
        _ = sourceMoves.withUnsafeBytes { sqlite3_bind_blob(statement, 15, $0.baseAddress, Int32($0.count), transient) }
        _ = packedTags.withUnsafeBytes { sqlite3_bind_blob(statement, 16, $0.baseAddress, Int32($0.count), transient) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }
}
