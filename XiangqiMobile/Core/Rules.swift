import Foundation

public extension Position {
    func legalMoves() -> [Move] {
        pseudoLegalMoves(for: sideToMove).filter { move in
            guard let next = try? applying(move, validate: false) else { return false }
            return !next.isInCheck(sideToMove)
        }.sorted { $0.uci < $1.uci }
    }

    func legalMoves(from square: Square) -> [Move] {
        legalMoves().filter { $0.from == square }
    }

    func isInCheck(_ side: Side) -> Bool {
        guard let generalSquare = pieces.first(where: {
            $0.value.side == side && $0.value.kind == .general
        })?.key else { return true }
        return pieces.contains { square, piece in
            piece.side == side.opponent && attacks(piece: piece, from: square, target: generalSquare)
        }
    }

    func result(repetitionCount: Int = 0) -> GameResult? {
        if repetitionCount >= 3 { return GameResult(winner: nil, reason: .repetition) }
        let moves = legalMoves()
        guard moves.isEmpty else { return nil }
        return GameResult(winner: sideToMove.opponent, reason: isInCheck(sideToMove) ? .checkmate : .stalemate)
    }

    private func pseudoLegalMoves(for side: Side) -> [Move] {
        var result: [Move] = []
        for (square, piece) in pieces where piece.side == side {
            for rank in 0...9 {
                for file in 0...8 {
                    let target = Square(file: file, rank: rank)
                    if pieces[target]?.side == side { continue }
                    if attacks(piece: piece, from: square, target: target) {
                        result.append(Move(from: square, to: target))
                    }
                }
            }
        }
        return result
    }

    private func attacks(piece: Piece, from: Square, target: Square) -> Bool {
        guard from != target, target.isValid else { return false }
        let dx = target.file - from.file
        let dy = target.rank - from.rank
        let ax = abs(dx)
        let ay = abs(dy)

        switch piece.kind {
        case .general:
            if target.file == from.file,
               pieces[target]?.kind == .general,
               pieces[target]?.side == piece.side.opponent {
                return countBetween(from, target) == 0
            }
            return ax + ay == 1 && inPalace(target, side: piece.side)

        case .advisor:
            return ax == 1 && ay == 1 && inPalace(target, side: piece.side)

        case .elephant:
            guard ax == 2, ay == 2 else { return false }
            if piece.side == .red && target.rank > 4 { return false }
            if piece.side == .black && target.rank < 5 { return false }
            return pieces[Square(file: from.file + dx / 2, rank: from.rank + dy / 2)] == nil

        case .horse:
            guard (ax == 1 && ay == 2) || (ax == 2 && ay == 1) else { return false }
            let leg = ax == 2
                ? Square(file: from.file + dx.signum(), rank: from.rank)
                : Square(file: from.file, rank: from.rank + dy.signum())
            return pieces[leg] == nil

        case .chariot:
            return (dx == 0 || dy == 0) && countBetween(from, target) == 0

        case .cannon:
            guard dx == 0 || dy == 0 else { return false }
            let blockers = countBetween(from, target)
            return pieces[target] == nil ? blockers == 0 : blockers == 1

        case .soldier:
            if dx == 0 && dy == piece.side.forward { return true }
            let crossedRiver = piece.side == .red ? from.rank >= 5 : from.rank <= 4
            return crossedRiver && ay == 0 && ax == 1
        }
    }

    private func inPalace(_ square: Square, side: Side) -> Bool {
        guard (3...5).contains(square.file) else { return false }
        return side == .red ? (0...2).contains(square.rank) : (7...9).contains(square.rank)
    }

    private func countBetween(_ from: Square, _ to: Square) -> Int {
        guard from.file == to.file || from.rank == to.rank else { return Int.max }
        let dx = (to.file - from.file).signum()
        let dy = (to.rank - from.rank).signum()
        var current = Square(file: from.file + dx, rank: from.rank + dy)
        var count = 0
        while current != to {
            if pieces[current] != nil { count += 1 }
            current = Square(file: current.file + dx, rank: current.rank + dy)
        }
        return count
    }
}
