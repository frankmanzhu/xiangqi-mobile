import Foundation

public struct ComputerConfiguration: Sendable {
    public let level: Int
    public let seed: UInt64

    public init(level: Int, seed: UInt64) {
        self.level = min(max(level, 1), 5)
        self.seed = seed
    }
}

public protocol ComputerPlayerClient: Sendable {
    var policyID: String { get }

    func chooseMove(
        startingFEN: String,
        moves: [String],
        configuration: ComputerConfiguration
    ) async throws -> Move

    func stop() async
}

public extension ComputerPlayerClient {
    func stop() async {}
}
