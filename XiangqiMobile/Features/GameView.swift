import SwiftUI

struct GameView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var session: GameSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.l10n) private var l10n

    /// A game is played in the theme it was started with, so a record reopened
    /// later looks the way it did when it was saved.
    private var theme: Theme { ThemeRegistry.theme(session.record.theme) }
    private var colors: ThemeColors { theme.colors }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 10) {
                playerRail(side: session.record.orientation.opponent, isOpponent: true)
                status
                BoardView(session: session)
                    .padding(.horizontal, 8)
                playerRail(side: session.record.orientation, isOpponent: false)
                if let pending = session.pendingMove { confirmationBar(pending) }
                else { actionDock }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .readableContentWidth()
        }
        .theme(theme)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { app.leaveGame() } label: { Image(systemName: "chevron.backward") }
                    .accessibilityLabel(l10n(L10n.Game.leave))
            }
            ToolbarItem(placement: .principal) {
                Text(session.record.mode.titleKey, l10n).font(.headline)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { session.showMenu = true } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel(l10n(L10n.Game.menu))
            }
        }
        .sheet(isPresented: $session.showHistory) { MoveHistoryView(session: session) }
        .sheet(isPresented: $session.showMenu) { GameMenuView(session: session) }
        .sheet(isPresented: $session.showResult) { ResultView(session: session) }
        .overlay(alignment: .top) {
            if let message = session.message {
                Text(verbatim: message.text(l10n))
                    .font(.subheadline.weight(.medium)).padding(10)
                    .background(.red.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white).padding(.top, 4)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await session.pause() } }
            else { Task { await session.startIfNeeded() } }
        }
        .onAppear {
            FeedbackPlayer.shared.prepare()
            Task { await session.startIfNeeded() }
        }
        .onDisappear { Task { await session.pause() } }
    }

    private var status: some View {
        HStack(spacing: 8) {
            if session.isThinking { ProgressView().controlSize(.small) }
            if session.position.isInCheck(session.position.sideToMove) && session.record.result == nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(colors.accent)
            }
            Text(verbatim: session.status.text(l10n))
                .font(.subheadline.weight(.semibold)).lineLimit(1)
        }
        .frame(height: 28)
        .accessibilityElement(children: .combine)
    }

    private func playerRail(side: Side, isOpponent: Bool) -> some View {
        let isActive = session.record.result == nil && session.position.sideToMove == side
        return HStack {
            Circle().fill(side == .red ? colors.red : colors.black).frame(width: 10, height: 10)
            Text(verbatim: label(for: side)).font(.subheadline.weight(.semibold))
            Spacer()
            if let seconds = side == .red ? session.record.redSecondsRemaining : session.record.blackSecondsRemaining {
                Text(verbatim: clock(seconds))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            } else {
                Text(railStateKey(isActive: isActive, isOpponent: isOpponent), l10n)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isActive ? colors.accent : .secondary)
            }
        }
        .padding(.horizontal, 12).frame(height: 42)
        .background(colors.surface.opacity(0.82), in: theme.cardShape(14))
        .overlay {
            theme.cardShape(14).stroke(
                isActive ? colors.accent.opacity(0.55) : theme.border,
                lineWidth: isActive ? 1.5 : 1
            )
        }
    }

    private func railStateKey(isActive: Bool, isOpponent: Bool) -> LocalizedKey {
        if isActive { return L10n.Game.Rail.toMove }
        return isOpponent ? L10n.Game.Rail.opponent : L10n.Game.Rail.player
    }

    private var actionDock: some View {
        HStack(spacing: 6) {
            action(
                L10n.Game.undo,
                "arrow.uturn.backward",
                enabled: session.record.timeControl == .casual && !session.record.moves.isEmpty
            ) { Task { await session.undo() } }
            if session.record.mode == .computer {
                action(hintTitle, "lightbulb", enabled: session.canInteract) {
                    Task { await session.hint() }
                }
            }
            action(L10n.Game.flip, "arrow.triangle.2.circlepath", enabled: true) { session.flip() }
            action(L10n.Game.movesAction, "list.number", enabled: !session.record.moves.isEmpty) {
                session.showHistory = true
            }
        }
        .frame(height: 58)
    }

    private func confirmationBar(_ move: Move) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Game.confirmMove, l10n).font(.caption).foregroundStyle(.secondary)
                Text(verbatim: move.uci).font(.headline.monospaced())
            }
            Spacer()
            Button(l10n(L10n.Common.cancel)) { session.cancelPendingMove() }
                .buttonStyle(.bordered)
            Button(l10n(L10n.Common.confirm)) { Task { await session.confirmPendingMove() } }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12).frame(height: 58)
        .background(colors.surface, in: theme.cardShape(14))
    }

    private func action(
        _ title: LocalizedKey,
        _ icon: String,
        enabled: Bool,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.body.weight(.semibold))
                Text(title, l10n).font(.caption2.weight(.medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(colors.surface, in: theme.controlShape)
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.42)
    }

    private var hintTitle: LocalizedKey {
        switch session.hintStage {
        case .available: L10n.Game.Hint.available
        case .searching: L10n.Game.Hint.searching
        case .source: L10n.Game.Hint.source
        case .destination: L10n.Game.Hint.destination
        }
    }

    private func label(for side: Side) -> String {
        let sideName = l10n(side.titleKey)
        if session.record.mode == .localTwoPlayer { return sideName }
        if side == session.record.humanSide {
            return l10n(L10n.Game.Rail.you, sideName)
        }
        return l10n(L10n.Game.Rail.engine, session.record.computerLevel)
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
