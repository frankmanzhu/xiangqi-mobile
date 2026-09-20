import SwiftUI

struct BoardView: View {
    @ObservedObject var session: GameSession
    let palette: BoardPalette
    @State private var dragStart: Square?

    var body: some View {
        GeometryReader { geometry in
            let metrics = Metrics(size: geometry.size)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(palette.board)
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                boardLines(metrics)
                stateMarkers(metrics)
                touchGrid(metrics)
                pieces(metrics)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture(metrics))
        }
        .aspectRatio(0.87, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Xiangqi board")
    }

    private func boardLines(_ metrics: Metrics) -> some View {
        Canvas { context, _ in
            var path = Path()
            for row in 0...9 {
                path.move(to: metrics.point(column: 0, row: row))
                path.addLine(to: metrics.point(column: 8, row: row))
            }
            for column in 0...8 {
                if column == 0 || column == 8 {
                    path.move(to: metrics.point(column: column, row: 0))
                    path.addLine(to: metrics.point(column: column, row: 9))
                } else {
                    path.move(to: metrics.point(column: column, row: 0))
                    path.addLine(to: metrics.point(column: column, row: 4))
                    path.move(to: metrics.point(column: column, row: 5))
                    path.addLine(to: metrics.point(column: column, row: 9))
                }
            }
            for top in [0, 7] {
                path.move(to: metrics.point(column: 3, row: top))
                path.addLine(to: metrics.point(column: 5, row: top + 2))
                path.move(to: metrics.point(column: 5, row: top))
                path.addLine(to: metrics.point(column: 3, row: top + 2))
            }
            context.stroke(path, with: .color(palette.line.opacity(0.84)), lineWidth: 1.15)
        }
        .overlay(alignment: .center) {
            HStack {
                Text("楚 河")
                Spacer()
                Text("漢 界")
            }
            .font(.system(size: max(13, metrics.step * 0.28), weight: .semibold, design: .serif))
            .foregroundStyle(palette.line.opacity(0.72))
            .padding(.horizontal, metrics.inset + metrics.step * 0.8)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func stateMarkers(_ metrics: Metrics) -> some View {
        if let last = session.lastMove {
            marker(at: last.from, metrics: metrics, color: palette.accent.opacity(0.3), style: .corners)
            marker(at: last.to, metrics: metrics, color: palette.accent.opacity(0.45), style: .corners)
        }
        if let selected = session.selectedSquare {
            marker(at: selected, metrics: metrics, color: palette.accent, style: .ring)
        }
        ForEach(Array(session.legalDestinations).sorted(), id: \.self) { square in
            let occupied = session.position.piece(at: square) != nil
            marker(at: square, metrics: metrics, color: palette.legal, style: occupied ? .ring : .dot)
        }
        switch session.hintStage {
        case .source(let move):
            marker(at: move.from, metrics: metrics, color: palette.legal, style: .hint)
        case .destination(let move):
            marker(at: move.from, metrics: metrics, color: palette.legal, style: .hint)
            marker(at: move.to, metrics: metrics, color: palette.legal, style: .ring)
        default: EmptyView()
        }
    }

    private enum MarkerStyle { case dot, ring, corners, hint }

    private func marker(at square: Square, metrics: Metrics, color: Color, style: MarkerStyle) -> some View {
        let point = metrics.point(for: square, orientation: session.record.orientation)
        return Group {
            switch style {
            case .dot:
                Circle().fill(color).frame(width: metrics.step * 0.22, height: metrics.step * 0.22)
            case .ring:
                Circle().stroke(color, lineWidth: 3).frame(width: metrics.pieceSize + 6, height: metrics.pieceSize + 6)
            case .corners:
                RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3)
                    .frame(width: metrics.pieceSize + 5, height: metrics.pieceSize + 5)
            case .hint:
                Circle().stroke(color, style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
                    .frame(width: metrics.pieceSize + 9, height: metrics.pieceSize + 9)
                    .overlay(Image(systemName: "lightbulb.fill").font(.caption).foregroundStyle(color).offset(x: metrics.pieceSize / 2, y: -metrics.pieceSize / 2))
            }
        }
        .position(point)
        .allowsHitTesting(false)
    }

    private func touchGrid(_ metrics: Metrics) -> some View {
        ForEach(0..<90, id: \.self) { index in
            let square = Square(file: index % 9, rank: index / 9)
            let point = metrics.point(for: square, orientation: session.record.orientation)
            Button { Task { await session.tap(square) } } label: {
                Color.clear.contentShape(Rectangle())
            }
            .frame(width: metrics.step, height: metrics.step)
            .position(point)
            .accessibilityLabel(accessibilityLabel(for: square))
            .accessibilityHint(session.legalDestinations.contains(square) ? "Legal destination" : "")
        }
    }

    private func pieces(_ metrics: Metrics) -> some View {
        ForEach(session.displayedPosition.pieces.sorted(by: { $0.key < $1.key }), id: \.value.id) { square, piece in
            let point = metrics.point(for: square, orientation: session.record.orientation)
            PieceView(piece: piece, palette: palette, size: metrics.pieceSize)
                .position(point)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func dragGesture(_ metrics: Metrics) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragStart == nil { dragStart = metrics.square(at: value.startLocation, orientation: session.record.orientation) }
            }
            .onEnded { value in
                let from = dragStart
                dragStart = nil
                guard let from, let to = metrics.square(at: value.location, orientation: session.record.orientation) else { return }
                Task { await session.drag(from: from, to: to) }
            }
    }

    private func accessibilityLabel(for square: Square) -> String {
        guard let piece = session.displayedPosition.piece(at: square) else { return "Empty \(square.uci)" }
        let state = piece.side == session.displayedPosition.sideToMove ? "selectable" : "occupied"
        return "\(piece.side.title) \(piece.kind.englishName), \(square.uci), \(state)"
    }
}

private struct PieceView: View {
    let piece: Piece
    let palette: BoardPalette
    let size: CGFloat
    @AppStorage("pieceLabels") private var pieceLabels = "Traditional"

    var body: some View {
        Circle()
            .fill(palette.surface)
            .overlay(Circle().stroke(piece.side == .red ? palette.red : palette.black, lineWidth: 2))
            .overlay(
                Text(glyph)
                    .font(.system(size: size * 0.57, weight: .bold, design: .serif))
                    .foregroundStyle(piece.side == .red ? palette.red : palette.black)
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private var glyph: String {
        if pieceLabels == "Simplified" {
            switch (piece.side, piece.kind) {
            case (.red, .general): return "帅"
            case (.black, .general): return "将"
            case (.red, .advisor): return "仕"
            case (.black, .advisor): return "士"
            case (.red, .elephant): return "相"
            case (.black, .elephant): return "象"
            case (_, .horse): return "马"
            case (_, .chariot): return "车"
            case (_, .cannon): return "炮"
            case (.red, .soldier): return "兵"
            case (.black, .soldier): return "卒"
            }
        }
        switch (piece.side, piece.kind) {
        case (.red, .general): return "帥"
        case (.black, .general): return "將"
        case (.red, .advisor): return "仕"
        case (.black, .advisor): return "士"
        case (.red, .elephant): return "相"
        case (.black, .elephant): return "象"
        case (_, .horse): return "馬"
        case (_, .chariot): return "車"
        case (_, .cannon): return "炮"
        case (.red, .soldier): return "兵"
        case (.black, .soldier): return "卒"
        }
    }
}

private struct Metrics {
    let size: CGSize
    let inset: CGFloat
    let step: CGFloat
    let pieceSize: CGFloat

    init(size: CGSize) {
        self.size = size
        let safeWidth = size.width.isFinite ? max(size.width, 80) : 80
        self.inset = min(22, max(8, safeWidth * 0.055))
        self.step = max(1, (safeWidth - inset * 2) / 8)
        self.pieceSize = max(1, min(44, step * 0.82))
    }

    func point(column: Int, row: Int) -> CGPoint {
        CGPoint(x: inset + CGFloat(column) * step, y: inset + CGFloat(row) * step)
    }

    func point(for square: Square, orientation: Side) -> CGPoint {
        let column = orientation == .red ? square.file : 8 - square.file
        let row = orientation == .red ? 9 - square.rank : square.rank
        return point(column: column, row: row)
    }

    func square(at point: CGPoint, orientation: Side) -> Square? {
        let column = Int(((point.x - inset) / step).rounded())
        let row = Int(((point.y - inset) / step).rounded())
        guard (0...8).contains(column), (0...9).contains(row) else { return nil }
        return orientation == .red
            ? Square(file: column, rank: 9 - row)
            : Square(file: 8 - column, rank: row)
    }
}

struct ReadOnlyBoardView: View {
    let position: Position
    let orientation: Side
    let palette: BoardPalette
    let lastMove: Move?

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(size: proxy.size)
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(palette.board)
                grid(metrics)
                if let lastMove {
                    studyMarker(at: lastMove.from, metrics: metrics, opacity: 0.28)
                    studyMarker(at: lastMove.to, metrics: metrics, opacity: 0.5)
                }
                ForEach(position.pieces.sorted(by: { $0.key < $1.key }), id: \.value.id) { square, piece in
                    PieceView(piece: piece, palette: palette, size: metrics.pieceSize)
                        .position(metrics.point(for: square, orientation: orientation))
                }
            }
        }
        .aspectRatio(8.0 / 9.25, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Study board")
    }

    private func grid(_ metrics: Metrics) -> some View {
        Canvas { context, _ in
            var path = Path()
            for row in 0...9 {
                path.move(to: metrics.point(column: 0, row: row))
                path.addLine(to: metrics.point(column: 8, row: row))
            }
            for column in 0...8 {
                if column == 0 || column == 8 {
                    path.move(to: metrics.point(column: column, row: 0))
                    path.addLine(to: metrics.point(column: column, row: 9))
                } else {
                    path.move(to: metrics.point(column: column, row: 0))
                    path.addLine(to: metrics.point(column: column, row: 4))
                    path.move(to: metrics.point(column: column, row: 5))
                    path.addLine(to: metrics.point(column: column, row: 9))
                }
            }
            path.move(to: metrics.point(column: 3, row: 0)); path.addLine(to: metrics.point(column: 5, row: 2))
            path.move(to: metrics.point(column: 5, row: 0)); path.addLine(to: metrics.point(column: 3, row: 2))
            path.move(to: metrics.point(column: 3, row: 7)); path.addLine(to: metrics.point(column: 5, row: 9))
            path.move(to: metrics.point(column: 5, row: 7)); path.addLine(to: metrics.point(column: 3, row: 9))
            context.stroke(path, with: .color(palette.line), lineWidth: 1.2)
        }
        .overlay(alignment: .center) {
            HStack {
                Text("楚 河")
                Spacer()
                Text("漢 界")
            }
            .font(.system(size: max(13, metrics.step * 0.28), weight: .semibold, design: .serif))
            .foregroundStyle(palette.line.opacity(0.72))
            .padding(.horizontal, metrics.inset + metrics.step * 0.8)
        }
    }

    private func studyMarker(at square: Square, metrics: Metrics, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .stroke(palette.accent.opacity(opacity), lineWidth: 3)
            .frame(width: metrics.pieceSize + 5, height: metrics.pieceSize + 5)
            .position(metrics.point(for: square, orientation: orientation))
    }
}

struct PracticeBoardView: View {
    let position: Position
    let orientation: Side
    let palette: BoardPalette
    let lastMove: Move?
    let selectedSquare: Square?
    let legalDestinations: Set<Square>
    let onTap: (Square) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(size: proxy.size)
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(palette.board)
                grid(metrics)
                if let lastMove {
                    marker(at: lastMove.from, metrics: metrics, color: palette.accent.opacity(0.28), ring: true)
                    marker(at: lastMove.to, metrics: metrics, color: palette.accent.opacity(0.5), ring: true)
                }
                if let selectedSquare {
                    marker(at: selectedSquare, metrics: metrics, color: palette.accent, ring: true)
                }
                ForEach(Array(legalDestinations).sorted(), id: \.self) { square in
                    marker(
                        at: square,
                        metrics: metrics,
                        color: palette.legal,
                        ring: position.piece(at: square) != nil
                    )
                }
                ForEach(position.pieces.sorted(by: { $0.key < $1.key }), id: \.value.id) { square, piece in
                    PieceView(piece: piece, palette: palette, size: metrics.pieceSize)
                        .position(metrics.point(for: square, orientation: orientation))
                        .allowsHitTesting(false)
                }
                ForEach(0..<90, id: \.self) { index in
                    let square = Square(file: index % 9, rank: index / 9)
                    Button { onTap(square) } label: { Color.clear.contentShape(Rectangle()) }
                        .frame(width: metrics.step, height: metrics.step)
                        .position(metrics.point(for: square, orientation: orientation))
                        .accessibilityLabel(square.uci)
                }
            }
        }
        .aspectRatio(8.0 / 9.25, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Practice board")
    }

    private func grid(_ metrics: Metrics) -> some View {
        Canvas { context, _ in
            var path = Path()
            for row in 0...9 {
                path.move(to: metrics.point(column: 0, row: row))
                path.addLine(to: metrics.point(column: 8, row: row))
            }
            for column in 0...8 {
                if column == 0 || column == 8 {
                    path.move(to: metrics.point(column: column, row: 0))
                    path.addLine(to: metrics.point(column: column, row: 9))
                } else {
                    path.move(to: metrics.point(column: column, row: 0))
                    path.addLine(to: metrics.point(column: column, row: 4))
                    path.move(to: metrics.point(column: column, row: 5))
                    path.addLine(to: metrics.point(column: column, row: 9))
                }
            }
            path.move(to: metrics.point(column: 3, row: 0)); path.addLine(to: metrics.point(column: 5, row: 2))
            path.move(to: metrics.point(column: 5, row: 0)); path.addLine(to: metrics.point(column: 3, row: 2))
            path.move(to: metrics.point(column: 3, row: 7)); path.addLine(to: metrics.point(column: 5, row: 9))
            path.move(to: metrics.point(column: 5, row: 7)); path.addLine(to: metrics.point(column: 3, row: 9))
            context.stroke(path, with: .color(palette.line), lineWidth: 1.2)
        }
        .overlay(alignment: .center) {
            HStack { Text("楚 河"); Spacer(); Text("漢 界") }
                .font(.system(size: max(13, metrics.step * 0.28), weight: .semibold, design: .serif))
                .foregroundStyle(palette.line.opacity(0.72))
                .padding(.horizontal, metrics.inset + metrics.step * 0.8)
        }
        .allowsHitTesting(false)
    }

    private func marker(at square: Square, metrics: Metrics, color: Color, ring: Bool) -> some View {
        Group {
            if ring {
                Circle().stroke(color, lineWidth: 3)
                    .frame(width: metrics.pieceSize + 6, height: metrics.pieceSize + 6)
            } else {
                Circle().fill(color).frame(width: metrics.step * 0.22, height: metrics.step * 0.22)
            }
        }
        .position(metrics.point(for: square, orientation: orientation))
        .allowsHitTesting(false)
    }
}
