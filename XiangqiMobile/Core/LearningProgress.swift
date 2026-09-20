import Foundation

public struct LearningItemProgress: Codable, Equatable, Sendable {
    public var isBookmarked: Bool
    public var lastPly: Int
    public var attempts: Int
    public var completions: Int
    public var updatedAt: Date

    public init(
        isBookmarked: Bool = false,
        lastPly: Int = 0,
        attempts: Int = 0,
        completions: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.isBookmarked = isBookmarked
        self.lastPly = max(0, lastPly)
        self.attempts = max(0, attempts)
        self.completions = max(0, completions)
        self.updatedAt = updatedAt
    }
}

public struct LearningProgressSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public var items: [String: LearningItemProgress]

    public init(schemaVersion: Int = Self.currentSchemaVersion, items: [String: LearningItemProgress] = [:]) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

public enum LearningProgressError: Error, Equatable {
    case unsupportedSchema(Int)
}

public actor LearningProgressStore {
    private let fileURL: URL
    private var cached: LearningProgressSnapshot?

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("XiangqiMobile", isDirectory: true)
                .appendingPathComponent("learning-progress.json")
        }
    }

    public func snapshot() throws -> LearningProgressSnapshot {
        if let cached { return cached }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let empty = LearningProgressSnapshot()
            cached = empty
            return empty
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LearningProgressSnapshot.self, from: Data(contentsOf: fileURL))
        guard decoded.schemaVersion == LearningProgressSnapshot.currentSchemaVersion else {
            throw LearningProgressError.unsupportedSchema(decoded.schemaVersion)
        }
        cached = decoded
        return decoded
    }

    public func progress(for id: String) throws -> LearningItemProgress {
        try snapshot().items[id] ?? LearningItemProgress()
    }

    @discardableResult
    public func toggleBookmark(for id: String) throws -> LearningItemProgress {
        var state = try snapshot()
        var item = state.items[id] ?? LearningItemProgress()
        item.isBookmarked.toggle()
        item.updatedAt = Date()
        state.items[id] = item
        try save(state)
        return item
    }

    public func recordOpened(_ id: String, lastPly: Int = 0) throws {
        var state = try snapshot()
        var item = state.items[id] ?? LearningItemProgress()
        item.attempts += 1
        item.lastPly = max(0, lastPly)
        item.updatedAt = Date()
        state.items[id] = item
        try save(state)
    }

    public func updateLastPly(_ ply: Int, for id: String) throws {
        var state = try snapshot()
        var item = state.items[id] ?? LearningItemProgress()
        item.lastPly = max(0, ply)
        item.updatedAt = Date()
        state.items[id] = item
        try save(state)
    }

    public func recordCompletion(for id: String, finalPly: Int) throws {
        var state = try snapshot()
        var item = state.items[id] ?? LearningItemProgress()
        item.completions += 1
        item.lastPly = max(0, finalPly)
        item.updatedAt = Date()
        state.items[id] = item
        try save(state)
    }

    public func bookmarkedIDs() throws -> [String] {
        try snapshot().items
            .filter(\.value.isBookmarked)
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
            .map(\.key)
    }

    private func save(_ snapshot: LearningProgressSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: fileURL, options: [.atomic, .completeFileProtection])
        cached = snapshot
    }
}
