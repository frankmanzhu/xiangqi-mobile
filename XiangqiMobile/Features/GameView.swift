import SwiftUI

struct GameView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var session: GameSession
    @Environment(\.scenePhase) private var scenePhase

    private var palette: BoardPalette { .palette(for: session.record.theme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(spacing: 10) {
                playerRail(side: session.record.orientation.opponent, isOpponent: true)
                status
                BoardView(session: session, palette: palette)
                    .padding(.horizontal, 8)
                playerRail(side: session.record.orientation, isOpponent: false)
                if let pending = session.pendingMove { confirmationBar(pending) }
                else { actionDock }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { app.leaveGame() } label: { Image(systemName: "chevron.backward") }
                    .accessibilityLabel("Leave game")
            }
            ToolbarItem(placement: .principal) {
                Text(session.record.mode.title).font(.headline)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { session.showMenu = true } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Game menu")
            }
        }
        .sheet(isPresented: $session.showHistory) { MoveHistoryView(session: session) }
        .sheet(isPresented: $session.showMenu) { GameMenuView(session: session) }
        .sheet(isPresented: $session.showResult) { ResultView(session: session) }
        .overlay(alignment: .top) {
            if let message = session.message {
                Text(message).font(.subheadline.weight(.medium)).padding(10)
                    .background(.red.opacity(0.9), in: Capsule()).foregroundStyle(.white).padding(.top, 4)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await session.pause() } }
            else { Task { await session.startIfNeeded() } }
        }
        .onAppear { Task { await session.startIfNeeded() } }
        .onDisappear { Task { await session.pause() } }
    }

    private var status: some View {
        HStack(spacing: 8) {
            if session.isThinking { ProgressView().controlSize(.small) }
            if session.position.isInCheck(session.position.sideToMove) && session.record.result == nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(palette.accent)
            }
            Text(session.statusText).font(.subheadline.weight(.semibold)).lineLimit(1)
        }
        .frame(height: 28)
        .accessibilityElement(children: .combine)
    }

    private func playerRail(side: Side, isOpponent: Bool) -> some View {
        HStack {
            Circle().fill(side == .red ? palette.red : palette.black).frame(width: 10, height: 10)
            Text(label(for: side)).font(.subheadline.weight(.semibold))
            Spacer()
            if let seconds = side == .red ? session.record.redSecondsRemaining : session.record.blackSecondsRemaining {
                Text(clock(seconds)).font(.system(.body, design: .monospaced).weight(.semibold))
            } else {
                Text(isOpponent ? "OPPONENT" : "PLAYER").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).frame(height: 42)
        .background(palette.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
    }

    private var actionDock: some View {
        HStack(spacing: 6) {
            action("Undo", "arrow.uturn.backward", enabled: session.record.timeControl == .casual && !session.record.moves.isEmpty) {
                Task { await session.undo() }
            }
            if session.record.mode == .computer {
                action(hintTitle, "lightbulb", enabled: session.canInteract) { Task { await session.hint() } }
            }
            action("Flip", "arrow.triangle.2.circlepath", enabled: true) { session.flip() }
            action("Moves", "list.number", enabled: !session.record.moves.isEmpty) { session.showHistory = true }
        }
        .frame(height: 58)
    }

    private func confirmationBar(_ move: Move) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Confirm move").font(.caption).foregroundStyle(.secondary)
                Text(move.uci).font(.headline.monospaced())
            }
            Spacer()
            Button("Cancel") { session.cancelPendingMove() }.buttonStyle(.bordered)
            Button("Confirm") { Task { await session.confirmPendingMove() } }.buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12).frame(height: 58)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func action(_ title: String, _ icon: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.body.weight(.semibold))
                Text(title).font(.caption2.weight(.medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.42)
    }

    private var hintTitle: String {
        switch session.hintStage {
        case .available: "Hint"
        case .searching: "Finding"
        case .source: "Show square"
        case .destination: "Hint shown"
        }
    }

    private func label(for side: Side) -> String {
        if session.record.mode == .localTwoPlayer { return side.title }
        return side == session.record.humanSide ? "You · \(side.title)" : "Pikafish · Level \(session.record.computerLevel)"
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
