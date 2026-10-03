import Foundation

/// Deterministic legal positions from the Swift rules used by the board.
@main
struct RulesPlayouts {
    static func main() throws {
        var seed: UInt64 = 0x5849414e475149
        var positions = 0
        for _ in 0..<100 {
            var position = Position.standard
            var output = ""
            for _ in 0..<100 {
                let legal = position.legalMoves()
                output += position.fen + "\t" + legal.map(\.uci).joined(separator: " ") + "\n"
                positions += 1
                guard !legal.isEmpty else { break }
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let index = Int((seed >> 32) % UInt64(legal.count))
                position = try position.applying(legal[index], validate: false)
            }
            FileHandle.standardOutput.write(Data(output.utf8))
        }
        FileHandle.standardError.write(Data("Generated \(positions) positions from 100 capped random playouts.\n".utf8))
    }
}
