import SwiftUI

struct GameMenuView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var confirmResign = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { dismiss() } label: { Label("Resume", systemImage: "play.fill") }
                    ShareLink(item: session.shareText()) { Label("Share game record", systemImage: "square.and.arrow.up") }
                }
                Section("Game") {
                    Button(role: .destructive) { confirmResign = true } label: { Label("Resign", systemImage: "flag.fill") }
                        .disabled(session.record.result != nil)
                    Button { dismiss(); app.leaveGame() } label: { Label("Save and leave", systemImage: "house") }
                    Button { dismiss(); app.newGameFromGame(session.record.mode) } label: { Label("New game", systemImage: "plus.circle") }
                }
                Section("Record format") {
                    LabeledContent("Moves", value: "UCI coordinates")
                    LabeledContent("Rules", value: session.record.rulesPolicyID)
                    Text("The saved record uses the starting FEN and ordered UCI moves. Display notation is derived, so games can be replayed and exchanged without depending on the visual theme.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Game menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog("Resign this game?", isPresented: $confirmResign, titleVisibility: .visible) {
            Button("Resign", role: .destructive) { Task { await session.resign(); dismiss() } }
            Button("Cancel", role: .cancel) { }
        }
    }
}
