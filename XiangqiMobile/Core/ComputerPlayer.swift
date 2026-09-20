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
    func chooseMove(in position: Position, configuration: ComputerConfiguration) async -> Move?
}

public struct NativeComputerClient: ComputerPlayerClient {
    public let policyID = "native-search@1"
    public init() {}

    public func chooseMove(in position: Position, configuration: ComputerConfiguration) async -> Move? {
        await Task.detached(priority: .userInitiated) {
            NativeComputerPlayer.chooseMove(in: position, configuration: configuration)
        }.value
    }
}

public enum NativeComputerPlayer {
    public static func chooseMove(in position: Position, configuration: ComputerConfiguration) -> Move? {
        let moves = position.legalMoves()
        guard !moves.isEmpty else { return nil }

        // A third ply is useful in reduced positions but too expensive at the
        // 44-move opening branch factor for a responsive on-device opponent.
        let depth = configuration.level >= 5 && position.pieces.count <= 18
            ? 3
            : (configuration.level >= 3 ? 2 : 1)
        var evaluated: [(move: Move, score: Int)] = []
        evaluated.reserveCapacity(moves.count)
        for move in moves {
            guard let next = try? position.applying(move, validate: false) else { continue }
            let childScore = search(next, depth: depth - 1, alpha: -100_000, beta: 100_000)
            evaluated.append((move: move, score: -childScore))
        }
        evaluated.sort { lhs, rhs in
            lhs.1 == rhs.1 ? lhs.0.uci < rhs.0.uci : lhs.1 > rhs.1
        }
        if configuration.level <= 2 {
            let spread = configuration.level == 1 ? 5 : 3
            let candidates = Array(evaluated.prefix(min(spread, evaluated.count)))
            var generator = SeededGenerator(seed: configuration.seed)
            return candidates[Int.random(in: 0..<candidates.count, using: &generator)].0
        }
        return evaluated[0].0
    }

    private static func search(_ position: Position, depth: Int, alpha: Int, beta: Int) -> Int {
        if let result = position.result() {
            return result.winner == position.sideToMove ? 100_000 : -100_000
        }
        if depth == 0 { return evaluate(position) }
        var best = -100_000
        var lower = alpha
        for move in position.legalMoves() {
            guard let next = try? position.applying(move, validate: false) else { continue }
            let score = -search(next, depth: depth - 1, alpha: -beta, beta: -lower)
            best = max(best, score)
            lower = max(lower, score)
            if lower >= beta { break }
        }
        return best
    }

    private static func evaluate(_ position: Position) -> Int {
        let perspective = position.sideToMove
        return position.pieces.values.reduce(0) { total, piece in
            total + (piece.side == perspective ? piece.kind.value : -piece.kind.value)
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
