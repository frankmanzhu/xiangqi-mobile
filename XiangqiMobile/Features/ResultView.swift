import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l10n

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(
                systemName: session.record.result?.winner == nil
                    ? "equal.circle.fill"
                    : "flag.checkered.circle.fill"
            )
            .font(.system(size: 64)).foregroundStyle(.tint)
            Text(verbatim: resultTitle).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(verbatim: resultReason).font(.title3).foregroundStyle(.secondary)
            HStack(spacing: 24) {
                summary(L10n.Result.Summary.moves, "\(session.record.moves.count)")
                summary(L10n.Result.Summary.time, duration(session.record.elapsedSeconds))
                summary(
                    L10n.Result.Summary.hints,
                    "\(session.record.moves.filter(\.hintUsed).count)"
                )
            }
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            Spacer()
            Button(l10n(L10n.Result.review)) {
                dismiss(); session.showHistory = true
            }
            .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            Button(l10n(L10n.Common.home)) { dismiss(); app.leaveGame() }
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(28)
        .readableContentWidth()
        .interactiveDismissDisabled(false)
    }

    private var resultTitle: String {
        guard let result = session.record.result else { return l10n(L10n.Result.complete) }
        guard let winner = result.winner else { return l10n(L10n.Result.draw) }
        return l10n(L10n.Result.wins, l10n(winner.titleKey))
    }

    private var resultReason: String {
        guard let reason = session.record.result?.reason else { return "" }
        return l10n(reason.titleKey)
    }

    private func summary(_ title: LocalizedKey, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: value).font(.headline)
            Text(title, l10n).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
