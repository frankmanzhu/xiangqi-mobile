import CryptoKit
import Foundation

enum PikafishError: LocalizedError {
    case networkMissing
    case networkInvalid
    case initialization(String)
    case position(String)
    case search(String)
    case invalidMove(String)

    var errorDescription: String? {
        switch self {
        case .networkMissing:
            return "The Pikafish neural network is missing from this build."
        case .networkInvalid:
            return "The Pikafish neural network failed its integrity check."
        case .initialization(let message), .position(let message), .search(let message):
            return message
        case .invalidMove(let move):
            return "Pikafish returned an invalid move: \(move)"
        }
    }
}

actor PikafishComputerClient: ComputerPlayerClient {
    static let revision = "6a59ee2f7b105bff64d9efc2692591107787e2b1"
    static let networkSHA256 = "7d13d73569a9b571ba0eb20cf1596247bc2a42738967e61afef6482b231e900e"

    nonisolated let policyID = "pikafish@\(revision)"
    private var nativeSession: NativePikafishSession?

    func prepare() throws {
        _ = try session()
    }

    func chooseMove(
        startingFEN: String,
        moves: [String],
        configuration: ComputerConfiguration
    ) async throws -> Move {
        let native = try session()
        let budget = Self.budget(for: configuration.level)
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try native.setPosition(startingFEN: startingFEN, moves: moves)
                let uci = try native.bestMove(moveTimeMilliseconds: budget)
                guard let move = Move(uci: uci) else { throw PikafishError.invalidMove(uci) }
                return move
            }.value
        } onCancel: {
            native.stop()
        }
    }

    func stop() async {
        nativeSession?.stop()
    }

    private func session() throws -> NativePikafishSession {
        if let nativeSession { return nativeSession }
        guard let networkURL = Bundle.main.url(forResource: "pikafish", withExtension: "nnue") else {
            throw PikafishError.networkMissing
        }
        guard try Self.sha256(of: networkURL) == Self.networkSHA256 else {
            throw PikafishError.networkInvalid
        }
        let created = try NativePikafishSession(networkURL: networkURL)
        nativeSession = created
        return created
    }

    private static func budget(for level: Int) -> Int32 {
        switch level {
        case 1: return 150
        case 2: return 350
        case 3: return 750
        case 4: return 1_500
        default: return 3_000
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            guard let data = try handle.read(upToCount: 1_048_576), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private final class NativePikafishSession: @unchecked Sendable {
    private let pointer: OpaquePointer
    private let lock = NSLock()

    init(networkURL: URL) throws {
        var error = PFEngineError()
        guard let pointer = networkURL.path.withCString({ pf_engine_create($0, &error) }) else {
            throw PikafishError.initialization(Self.message(from: &error))
        }
        self.pointer = pointer
    }

    deinit {
        pf_engine_destroy(pointer)
    }

    func setPosition(startingFEN: String, moves: [String]) throws {
        lock.lock()
        defer { lock.unlock() }
        var error = PFEngineError()
        let allocatedMoves = moves.map { strdup($0) }
        defer { allocatedMoves.forEach { free($0) } }
        let movePointers: [UnsafePointer<CChar>?] = allocatedMoves.map { pointer in
            guard let pointer else { return nil }
            return UnsafePointer(pointer)
        }
        let succeeded = startingFEN.withCString { fen in
            movePointers.withUnsafeBufferPointer { buffer in
                pf_engine_set_position(pointer, fen, buffer.baseAddress, buffer.count, &error)
            }
        }
        guard succeeded else { throw PikafishError.position(Self.message(from: &error)) }
    }

    func bestMove(moveTimeMilliseconds: Int32) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        var error = PFEngineError()
        var output = [CChar](repeating: 0, count: 6)
        let succeeded = output.withUnsafeMutableBufferPointer { buffer in
            pf_engine_best_move(pointer, moveTimeMilliseconds, 0, 0, buffer.baseAddress, &error)
        }
        guard succeeded else { throw PikafishError.search(Self.message(from: &error)) }
        return String(cString: output)
    }

    func stop() {
        pf_engine_stop(pointer)
    }

    private static func message(from error: inout PFEngineError) -> String {
        withUnsafePointer(to: &error.message) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 512) { String(cString: $0) }
        }
    }
}
