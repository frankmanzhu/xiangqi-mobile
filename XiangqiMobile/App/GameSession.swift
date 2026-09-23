import Combine
import Foundation

/// What the status line should say, as a value rather than a sentence.
///
/// Keeping this semantic lets the view render it in the selected language;
/// a session that formatted English here could not be translated.
enum GameStatus: Equatable {
    case win(Side, GameResultReason)
    case draw(GameResultReason)
    case reviewing(ply: Int, total: Int)
    case check(Side)
    case thinking
    case sideToMove(Side)
    case yourMove
    case computerToMove
}

/// A transient banner shown over the board.
enum GameMessage: Equatable {
    case engineMismatch
    case notSaved
    case failure(String)
}

enum HintStage: Equatable {
    case available
    case searching
    case source(Move)
    case destination(Move)
}

@MainActor
final class GameSession: ObservableObject {
    @Published private(set) var record: GameRecord
    @Published private(set) var position: Position
    @Published private(set) var selectedSquare: Square?
    @Published private(set) var legalDestinations: Set<Square> = []
    @Published private(set) var isThinking = false
    @Published private(set) var hintStage: HintStage = .available
    @Published private(set) var pendingMove: Move?
    @Published var replayPly: Int?
    @Published var showHistory = false
    @Published var showMenu = false
    @Published var showResult = false
    @Published var message: GameMessage?

    private let repository: GameRepository
    private let computer: any ComputerPlayerClient
    private var searchToken = UUID()
    private var positionVersion: UInt64 = 0
    private var hintUsedForCurrentPly = false
    private var clockTask: Task<Void, Never>?

    init(
        record: GameRecord,
        repository: GameRepository,
        computer: any ComputerPlayerClient = PikafishComputerClient()
    ) {
        self.record = record
        self.repository = repository
        self.computer = computer
        self.position = (try? Position(fen: record.startingFEN).replaying(record.uciMoves)) ?? .standard
        self.showResult = record.result != nil
        startClock()
    }

    deinit { clockTask?.cancel() }

    var displayedPosition: Position {
        guard let replayPly else { return position }
        return (try? Position(fen: record.startingFEN).replaying(Array(record.uciMoves.prefix(replayPly)))) ?? position
    }

    var isReplaying: Bool { replayPly != nil }
    var canInteract: Bool { record.isActive && !isThinking && !isReplaying && pendingMove == nil && isLocalTurn }
    var isLocalTurn: Bool {
        record.mode == .localTwoPlayer || position.sideToMove == record.humanSide
    }
    var lastMove: Move? { record.moves.last.flatMap { Move(uci: $0.uci) } }

    var status: GameStatus {
        if let result = record.result {
            guard let winner = result.winner else { return .draw(result.reason) }
            return .win(winner, result.reason)
        }
        if isReplaying { return .reviewing(ply: replayPly ?? 0, total: record.moves.count) }
        if position.isInCheck(position.sideToMove) { return .check(position.sideToMove) }
        if isThinking { return .thinking }
        if record.mode == .localTwoPlayer { return .sideToMove(position.sideToMove) }
        return isLocalTurn ? .yourMove : .computerToMove
    }

    func startIfNeeded() async {
        startClock()
        if record.mode == .computer && !isLocalTurn && record.isActive {
            await startComputerTurn()
        }
    }

    func pause() async {
        cancelSearch()
        clockTask?.cancel()
        clockTask = nil
        record.updatedAt = Date()
        await persist()
    }

    func tap(_ square: Square) async {
        guard canInteract else { return }
        if let selectedSquare, legalDestinations.contains(square) {
            await proposeOrCommit(Move(from: selectedSquare, to: square))
            return
        }
        if selectedSquare == square {
            clearSelection()
            return
        }
        if let piece = position.piece(at: square), piece.side == position.sideToMove {
            let moves = position.legalMoves(from: square)
            selectedSquare = square
            legalDestinations = Set(moves.map(\.to))
        } else {
            clearSelection()
        }
    }

    func drag(from: Square, to: Square) async {
        guard canInteract,
              position.piece(at: from)?.side == position.sideToMove,
              position.legalMoves(from: from).contains(where: { $0.to == to }) else { return }
        await proposeOrCommit(Move(from: from, to: to))
    }

    func confirmPendingMove() async {
        guard let pendingMove else { return }
        self.pendingMove = nil
        await commit(pendingMove, computerSeed: nil)
    }

    func cancelPendingMove() { pendingMove = nil }

    func hint() async {
        guard record.mode == .computer, canInteract else { return }
        switch hintStage {
        case .source(let move):
            hintStage = .destination(move)
        case .destination:
            break
        case .searching:
            break
        case .available:
            hintStage = .searching
            let snapshot = position
            let moves = record.uciMoves
            let seed = seedForCurrentPosition(salt: 0x48494E54)
            do {
                let move = try await computer.chooseMove(
                    startingFEN: record.startingFEN,
                    moves: moves,
                    configuration: .init(level: 3, seed: seed)
                )
                guard snapshot.fen == position.fen else {
                    hintStage = .available
                    return
                }
                hintUsedForCurrentPly = true
                hintStage = .source(move)
            } catch {
                hintStage = .available
                message = .failure(error.localizedDescription)
            }
        }
    }

    func undo() async {
        guard record.timeControl == .casual, !record.moves.isEmpty, record.result == nil else { return }
        cancelSearch()
        var removeCount = 1
        if record.mode == .computer {
            if record.moves.last?.side != record.humanSide { removeCount = min(2, record.moves.count) }
        }
        record.moves.removeLast(removeCount)
        position = (try? Position(fen: record.startingFEN).replaying(record.uciMoves)) ?? .standard
        record.updatedAt = Date()
        positionVersion &+= 1
        clearTransientState()
        await persist()
    }

    func resign() async {
        guard record.result == nil else { return }
        cancelSearch()
        let winner = record.mode == .computer ? record.humanSide?.opponent : position.sideToMove.opponent
        record.result = GameResult(winner: winner, reason: .resignation)
        record.updatedAt = Date()
        showResult = true
        await persist()
    }

    func flip() {
        record.orientation = record.orientation.opponent
        Task { await persist() }
    }

    func showReplay(at ply: Int) {
        clearSelection()
        replayPly = min(max(ply, 0), record.moves.count)
    }

    func stepReplay(_ delta: Int) {
        showReplay(at: (replayPly ?? record.moves.count) + delta)
    }

    func returnToLive() { replayPly = nil }

    func shareText() -> String {
        guard let data = try? PortableGame(record: record).encoded(),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    func cancelSearch() {
        searchToken = UUID()
        isThinking = false
        Task { await computer.stop() }
    }

    private func commit(_ move: Move, computerSeed: UInt64?) async {
        guard record.result == nil,
              position.legalMoves().contains(move),
              let movingPiece = position.piece(at: move.from) else { return }
        let before = position
        let captured = position.piece(at: move.to)?.kind
        guard let next = try? position.applying(move) else { return }
        let notation = MoveNotation.display(move: move, in: before)
        record.moves.append(RecordedMove(
            uci: move.uci,
            notation: notation,
            side: movingPiece.side,
            captured: captured,
            hintUsed: computerSeed == nil ? hintUsedForCurrentPly : false,
            engineSelectionSeed: computerSeed
        ))
        position = next
        positionVersion &+= 1
        record.updatedAt = Date()
        clearTransientState()

        let repetitions = repetitionCount(of: normalizedPositionKey(position))
        if let result = position.result(repetitionCount: repetitions) {
            record.result = result
            showResult = true
        }
        await persist()

        if record.mode == .computer && !isLocalTurn && record.isActive {
            await startComputerTurn()
        }
    }

    private func proposeOrCommit(_ move: Move) async {
        if UserDefaults.standard.bool(forKey: "confirmMoves") {
            pendingMove = move
        } else {
            await commit(move, computerSeed: nil)
        }
    }

    private func startComputerTurn() async {
        guard record.mode == .computer, !isLocalTurn, record.isActive, !isThinking else { return }
        let token = UUID()
        searchToken = token
        let version = positionVersion
        let snapshot = position
        let moves = record.uciMoves
        let level = record.computerLevel
        let seed = seedForCurrentPosition(salt: UInt64(record.moves.count))
        isThinking = true
        do {
            let move = try await computer.chooseMove(
                startingFEN: record.startingFEN,
                moves: moves,
                configuration: .init(level: level, seed: seed)
            )
            guard searchToken == token, positionVersion == version else { return }
            isThinking = false
            guard snapshot.fen == position.fen, position.legalMoves().contains(move) else {
                message = .engineMismatch
                return
            }
            await commit(move, computerSeed: nil)
        } catch {
            guard searchToken == token, positionVersion == version else { return }
            isThinking = false
            message = .failure(error.localizedDescription)
        }
    }

    private func persist() async {
        do {
            try await repository.save(record)
            message = nil
        } catch {
            message = .notSaved
        }
    }

    private func clearSelection() {
        selectedSquare = nil
        legalDestinations = []
    }

    private func clearTransientState() {
        clearSelection()
        pendingMove = nil
        hintStage = .available
        hintUsedForCurrentPly = false
        replayPly = nil
    }

    private func repetitionCount(of key: String) -> Int {
        var replay = (try? Position(fen: record.startingFEN)) ?? .standard
        var count = normalizedPositionKey(replay) == key ? 1 : 0
        for uci in record.uciMoves {
            guard let move = Move(uci: uci), let next = try? replay.applying(move) else { break }
            replay = next
            if normalizedPositionKey(replay) == key { count += 1 }
        }
        return count
    }

    private func normalizedPositionKey(_ position: Position) -> String {
        position.fen.split(separator: " ").prefix(2).joined(separator: " ")
    }

    private func seedForCurrentPosition(salt: UInt64) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(record.id)
        hasher.combine(positionVersion)
        return UInt64(bitPattern: Int64(hasher.finalize())) ^ salt
    }

    private func startClock() {
        guard record.timeControl != .casual, record.result == nil else { return }
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.record.result == nil else { return }
                self.tickClock()
            }
        }
    }

    private func tickClock() {
        record.elapsedSeconds += 1
        if position.sideToMove == .red {
            record.redSecondsRemaining = max(0, (record.redSecondsRemaining ?? 0) - 1)
            if record.redSecondsRemaining == 0 { finishOnTime(loser: .red) }
        } else {
            record.blackSecondsRemaining = max(0, (record.blackSecondsRemaining ?? 0) - 1)
            if record.blackSecondsRemaining == 0 { finishOnTime(loser: .black) }
        }
        if record.elapsedSeconds.isMultiple(of: 10) { Task { await persist() } }
    }

    private func finishOnTime(loser: Side) {
        cancelSearch()
        record.result = GameResult(winner: loser.opponent, reason: .timeLoss)
        record.updatedAt = Date()
        showResult = true
        Task { await persist() }
    }
}
