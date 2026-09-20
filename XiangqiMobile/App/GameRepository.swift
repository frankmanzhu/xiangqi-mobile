import Foundation

actor GameRepository {
    enum RepositoryError: Error {
        case unsupportedSchema(Int)
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("XiangqiMobile", isDirectory: true)
                .appendingPathComponent("active-game.json")
        }
    }

    func load() throws -> GameRecord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(GameRecord.self, from: data)
        guard record.schemaVersion == GameRecord.schemaVersion else {
            throw RepositoryError.unsupportedSchema(record.schemaVersion)
        }
        _ = try Position(fen: record.startingFEN).replaying(record.uciMoves)
        return record
    }

    func save(_ record: GameRecord) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
