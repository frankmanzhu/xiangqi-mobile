import SwiftUI

/// Point geometry for a 9x10 xiangqi grid inside a given size.
struct BoardGeometry {
    let size: CGSize
    let inset: CGFloat
    let step: CGFloat
    let pieceSize: CGFloat

    init(size: CGSize, pieceScale: CGFloat) {
        self.size = size
        let safeWidth = size.width.isFinite ? max(size.width, 80) : 80
        self.inset = min(22, max(8, safeWidth * 0.055))
        self.step = max(1, (safeWidth - inset * 2) / 8)
        self.pieceSize = max(1, min(44, step * pieceScale))
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

/// The board lines, palace diagonals, and river text.
///
/// Every board in the app draws through this one view, so a theme's line
/// weight and river colour apply everywhere without being restated.
struct BoardGrid: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let geometry: BoardGeometry

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            for row in 0...9 {
                path.move(to: geometry.point(column: 0, row: row))
                path.addLine(to: geometry.point(column: 8, row: row))
            }
            for column in 0...8 {
                if column == 0 || column == 8 {
                    path.move(to: geometry.point(column: column, row: 0))
                    path.addLine(to: geometry.point(column: column, row: 9))
                } else {
                    path.move(to: geometry.point(column: column, row: 0))
                    path.addLine(to: geometry.point(column: column, row: 4))
                    path.move(to: geometry.point(column: column, row: 5))
                    path.addLine(to: geometry.point(column: column, row: 9))
                }
            }
            for top in [0, 7] {
                path.move(to: geometry.point(column: 3, row: top))
                path.addLine(to: geometry.point(column: 5, row: top + 2))
                path.move(to: geometry.point(column: 5, row: top))
                path.addLine(to: geometry.point(column: 3, row: top + 2))
            }
            context.stroke(
                path,
                with: .color(theme.colors.line.opacity(0.84)),
                lineWidth: theme.metrics.gridLineWidth
            )
        }
        .overlay(alignment: .center) {
            HStack {
                Text(L10n.Board.River.left, l10n)
                Spacer()
                Text(L10n.Board.River.right, l10n)
            }
            .font(.system(size: max(13, geometry.step * 0.28), weight: .semibold, design: .serif))
            .foregroundStyle(theme.colors.river)
            .padding(.horizontal, geometry.inset + geometry.step * 0.8)
        }
        .allowsHitTesting(false)
    }
}

/// One piece, drawn in the active theme and glyph set.
struct PieceView: View {
    @Environment(\.theme) private var theme
    @AppStorage(PieceGlyphSet.storageKey) private var glyphSetRaw = PieceGlyphSet.traditional.rawValue
    let piece: Piece
    let size: CGFloat

    private var pieceColor: Color {
        piece.side == .red ? theme.colors.red : theme.colors.black
    }

    var body: some View {
        Circle()
            .fill(theme.colors.surface)
            .overlay(Circle().stroke(pieceColor, lineWidth: theme.metrics.pieceStrokeWidth))
            .overlay(
                Text(verbatim: PieceGlyphSet(storedValue: glyphSetRaw).glyph(for: piece))
                    .font(.system(size: size * 0.57, weight: .bold, design: .serif))
                    .foregroundStyle(pieceColor)
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
}

/// Markers layered over a board point.
enum BoardMarkerStyle { case dot, ring, corners, hint }

struct BoardMarker: View {
    @Environment(\.theme) private var theme
    let style: BoardMarkerStyle
    let color: Color
    let geometry: BoardGeometry

    var body: some View {
        switch style {
        case .dot:
            Circle().fill(color)
                .frame(width: geometry.step * 0.22, height: geometry.step * 0.22)
        case .ring:
            Circle().stroke(color, lineWidth: 3)
                .frame(width: geometry.pieceSize + 6, height: geometry.pieceSize + 6)
        case .corners:
            RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3)
                .frame(width: geometry.pieceSize + 5, height: geometry.pieceSize + 5)
        case .hint:
            Circle().stroke(color, style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
                .frame(width: geometry.pieceSize + 9, height: geometry.pieceSize + 9)
                .overlay(
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(color)
                        .offset(x: geometry.pieceSize / 2, y: -geometry.pieceSize / 2)
                )
        }
    }
}

/// The playable board.
struct BoardView: View {
    @ObservedObject var session: GameSession
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @State private var dragStart: Square?

    var body: some View {
        GeometryReader { proxy in
            let geometry = BoardGeometry(size: proxy.size, pieceScale: theme.metrics.pieceScale)
            ZStack {
                theme.boardShape
                    .fill(theme.colors.board)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                BoardGrid(geometry: geometry)
                stateMarkers(geometry)
                touchGrid(geometry)
                pieces(geometry)
            }
            .overlay {
                theme.boardShape.stroke(theme.colors.line.opacity(0.2), lineWidth: 1)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture(geometry))
        }
        .aspectRatio(0.87, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n(L10n.Board.label))
    }

    @ViewBuilder
    private func stateMarkers(_ geometry: BoardGeometry) -> some View {
        if let last = session.lastMove {
            marker(at: last.from, geometry, theme.colors.accent.opacity(0.3), .corners)
            marker(at: last.to, geometry, theme.colors.accent.opacity(0.45), .corners)
        }
        if let selected = session.selectedSquare {
            marker(at: selected, geometry, theme.colors.accent, .ring)
        }
        ForEach(Array(session.legalDestinations).sorted(), id: \.self) { square in
            let occupied = session.position.piece(at: square) != nil
            marker(at: square, geometry, theme.colors.legal, occupied ? .ring : .dot)
        }
        switch session.hintStage {
        case .source(let move):
            marker(at: move.from, geometry, theme.colors.legal, .hint)
        case .destination(let move):
            marker(at: move.from, geometry, theme.colors.legal, .hint)
            marker(at: move.to, geometry, theme.colors.legal, .ring)
        default: EmptyView()
        }
    }

    private func marker(
        at square: Square,
        _ geometry: BoardGeometry,
        _ color: Color,
        _ style: BoardMarkerStyle
    ) -> some View {
        BoardMarker(style: style, color: color, geometry: geometry)
            .position(geometry.point(for: square, orientation: session.record.orientation))
            .allowsHitTesting(false)
    }

    private func touchGrid(_ geometry: BoardGeometry) -> some View {
        ForEach(0..<90, id: \.self) { index in
            let square = Square(file: index % 9, rank: index / 9)
            Button { Task { await session.tap(square) } } label: {
                Color.clear.contentShape(Rectangle())
            }
            .frame(width: geometry.step, height: geometry.step)
            .position(geometry.point(for: square, orientation: session.record.orientation))
            .accessibilityLabel(accessibilityLabel(for: square))
            .accessibilityHint(
                session.legalDestinations.contains(square) ? l10n(L10n.Board.legalDestination) : ""
            )
        }
    }

    private func pieces(_ geometry: BoardGeometry) -> some View {
        ForEach(session.displayedPosition.pieces.sorted(by: { $0.key < $1.key }), id: \.value.id) { square, piece in
            PieceView(piece: piece, size: geometry.pieceSize)
                .position(geometry.point(for: square, orientation: session.record.orientation))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func dragGesture(_ geometry: BoardGeometry) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = geometry.square(
                        at: value.startLocation,
                        orientation: session.record.orientation
                    )
                }
            }
            .onEnded { value in
                let from = dragStart
                dragStart = nil
                guard let from,
                      let to = geometry.square(at: value.location, orientation: session.record.orientation)
                else { return }
                Task { await session.drag(from: from, to: to) }
            }
    }

    private func accessibilityLabel(for square: Square) -> String {
        guard let piece = session.displayedPosition.piece(at: square) else {
            return l10n(L10n.Board.Square.empty, square.uci)
        }
        let state = piece.side == session.displayedPosition.sideToMove
            ? L10n.Board.State.selectable
            : L10n.Board.State.occupied
        return l10n(
            L10n.Board.Square.occupied,
            l10n(piece.side.titleKey),
            l10n(piece.kind.titleKey),
            square.uci,
            l10n(state)
        )
    }
}

/// A board that only displays a position, used when studying a record.
struct ReadOnlyBoardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let position: Position
    let orientation: Side
    let lastMove: Move?

    var body: some View {
        GeometryReader { proxy in
            let geometry = BoardGeometry(size: proxy.size, pieceScale: theme.metrics.pieceScale)
            ZStack {
                theme.boardShape.fill(theme.colors.board)
                BoardGrid(geometry: geometry)
                if let lastMove {
                    marker(lastMove.from, geometry, opacity: 0.28)
                    marker(lastMove.to, geometry, opacity: 0.5)
                }
                ForEach(position.pieces.sorted(by: { $0.key < $1.key }), id: \.value.id) { square, piece in
                    PieceView(piece: piece, size: geometry.pieceSize)
                        .position(geometry.point(for: square, orientation: orientation))
                }
            }
        }
        .aspectRatio(8.0 / 9.25, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n(L10n.Board.study))
    }

    private func marker(_ square: Square, _ geometry: BoardGeometry, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .stroke(theme.colors.accent.opacity(opacity), lineWidth: 3)
            .frame(width: geometry.pieceSize + 5, height: geometry.pieceSize + 5)
            .position(geometry.point(for: square, orientation: orientation))
    }
}

/// A board the learner moves on, used for puzzle practice.
struct PracticeBoardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let position: Position
    let orientation: Side
    let lastMove: Move?
    let selectedSquare: Square?
    let legalDestinations: Set<Square>
    let onTap: (Square) -> Void

    var body: some View {
        GeometryReader { proxy in
            let geometry = BoardGeometry(size: proxy.size, pieceScale: theme.metrics.pieceScale)
            ZStack {
                theme.boardShape.fill(theme.colors.board)
                BoardGrid(geometry: geometry)
                if let lastMove {
                    marker(lastMove.from, geometry, theme.colors.accent.opacity(0.28), .ring)
                    marker(lastMove.to, geometry, theme.colors.accent.opacity(0.5), .ring)
                }
                if let selectedSquare {
                    marker(selectedSquare, geometry, theme.colors.accent, .ring)
                }
                ForEach(Array(legalDestinations).sorted(), id: \.self) { square in
                    marker(
                        square,
                        geometry,
                        theme.colors.legal,
                        position.piece(at: square) != nil ? .ring : .dot
                    )
                }
                ForEach(position.pieces.sorted(by: { $0.key < $1.key }), id: \.value.id) { square, piece in
                    PieceView(piece: piece, size: geometry.pieceSize)
                        .position(geometry.point(for: square, orientation: orientation))
                        .allowsHitTesting(false)
                }
                ForEach(0..<90, id: \.self) { index in
                    let square = Square(file: index % 9, rank: index / 9)
                    Button { onTap(square) } label: { Color.clear.contentShape(Rectangle()) }
                        .frame(width: geometry.step, height: geometry.step)
                        .position(geometry.point(for: square, orientation: orientation))
                        .accessibilityLabel(square.uci)
                }
            }
        }
        .aspectRatio(8.0 / 9.25, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n(L10n.Board.practice))
    }

    private func marker(
        _ square: Square,
        _ geometry: BoardGeometry,
        _ color: Color,
        _ style: BoardMarkerStyle
    ) -> some View {
        BoardMarker(style: style, color: color, geometry: geometry)
            .position(geometry.point(for: square, orientation: orientation))
            .allowsHitTesting(false)
    }
}
