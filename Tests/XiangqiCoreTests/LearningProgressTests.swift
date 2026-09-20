import Foundation
import XCTest
@testable import XiangqiCore

final class LearningProgressTests: XCTestCase {
    func testProgressPersistsAcrossStoreInstances() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LearningProgressTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("progress.json")
        let first = LearningProgressStore(fileURL: url)

        try await first.recordOpened("ccpd:開局/fixture")
        try await first.updateLastPly(7, for: "ccpd:開局/fixture")
        let bookmarked = try await first.toggleBookmark(for: "ccpd:開局/fixture")
        XCTAssertTrue(bookmarked.isBookmarked)
        try await first.recordCompletion(for: "ccpd:開局/fixture", finalPly: 12)

        let restored = try await LearningProgressStore(fileURL: url).progress(for: "ccpd:開局/fixture")
        XCTAssertEqual(restored.attempts, 1)
        XCTAssertEqual(restored.completions, 1)
        XCTAssertEqual(restored.lastPly, 12)
        XCTAssertTrue(restored.isBookmarked)
    }

    func testRejectsUnknownFutureSchema() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LearningProgressTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("progress.json")
        try Data("{\"schemaVersion\":99,\"items\":{}}".utf8).write(to: url)

        do {
            _ = try await LearningProgressStore(fileURL: url).snapshot()
            XCTFail("Expected unsupported schema")
        } catch let error as LearningProgressError {
            XCTAssertEqual(error, .unsupportedSchema(99))
        }
    }
}
