import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: session.record.result?.winner == nil ? "equal.circle.fill" : "flag.checkered.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.tint)
            Text(resultTitle).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(resultReason).font(.title3).foregroundStyle(.secondary)
            HStack(spacing: 24) {
                summary("Moves", "\(session.record.moves.count)")
                summary("Time", duration(session.record.elapsedSeconds))
                summary("Hints", "\(session.record.moves.filter(\.hintUsed).count)")
            }
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            Spacer()
            Button("Review moves") {
                dismiss(); session.showHistory = true
            }
            .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            Button("Home") { dismiss(); app.leaveGame() }
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(28)
        .interactiveDismissDisabled(false)
    }

    private var resultTitle: String {
        guard let result = session.record.result else { return "Game complete" }
        if let winner = result.winner { return "\(winner.title) wins" }
        return "Draw"
    }
    private var resultReason: String { session.record.result?.reason.rawValue.capitalized ?? "" }
    private func summary(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.headline); Text(title).font(.caption).foregroundStyle(.secondary) }
    }
    private func duration(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}
