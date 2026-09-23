import SwiftUI

struct GameMenuView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l10n
    @State private var confirmResign = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { dismiss() } label: {
                        Label(l10n(L10n.Common.resume), systemImage: "play.fill")
                    }
                    ShareLink(item: session.shareText()) {
                        Label(l10n(L10n.GameMenu.share), systemImage: "square.and.arrow.up")
                    }
                }
                Section(l10n(L10n.GameMenu.Section.game)) {
                    Button(role: .destructive) { confirmResign = true } label: {
                        Label(l10n(L10n.GameMenu.resign), systemImage: "flag.fill")
                    }
                    .disabled(session.record.result != nil)
                    Button { dismiss(); app.leaveGame() } label: {
                        Label(l10n(L10n.GameMenu.saveAndLeave), systemImage: "house")
                    }
                    Button { dismiss(); app.newGameFromGame(session.record.mode) } label: {
                        Label(l10n(L10n.GameMenu.newGame), systemImage: "plus.circle")
                    }
                }
                Section(l10n(L10n.GameMenu.Section.format)) {
                    LabeledContent(
                        l10n(L10n.Common.moves),
                        value: l10n(L10n.GameMenu.movesValue)
                    )
                    LabeledContent(l10n(L10n.GameMenu.rules), value: session.record.rulesPolicyID)
                    Text(L10n.GameMenu.formatNote, l10n)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(l10n(L10n.Game.menu))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n(L10n.Common.done)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog(
            l10n(L10n.GameMenu.resignConfirm),
            isPresented: $confirmResign,
            titleVisibility: .visible
        ) {
            Button(l10n(L10n.GameMenu.resign), role: .destructive) {
                Task { await session.resign(); dismiss() }
            }
            Button(l10n(L10n.Common.cancel), role: .cancel) { }
        }
    }
}
