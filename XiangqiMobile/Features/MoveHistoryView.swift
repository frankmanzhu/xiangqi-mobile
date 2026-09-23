import SwiftUI

struct MoveHistoryView: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l10n

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(Array(stride(from: 0, to: session.record.moves.count, by: 2)), id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text(L10n.History.moveNumber, l10n, index / 2 + 1)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                            moveButton(index)
                            if index + 1 < session.record.moves.count { moveButton(index + 1) }
                            else { Spacer().frame(maxWidth: .infinity) }
                        }
                    }
                }
                replayControls
            }
            .navigationTitle(l10n(L10n.History.title, session.record.moves.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: session.shareText()) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(l10n(L10n.GameMenu.share))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n(L10n.Common.done)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func moveButton(_ index: Int) -> some View {
        let move = session.record.moves[index]
        let selected = session.replayPly == index + 1
        return Button { session.showReplay(at: index + 1) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: move.notation).lineLimit(1)
                Text(verbatim: move.uci).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(selected ? .bold : .regular))
            .padding(.vertical, 6).padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(selected ? RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 1) : nil)
        }.buttonStyle(.plain)
    }

    private var replayControls: some View {
        HStack {
            Button { session.stepReplay(-1) } label: {
                Label(l10n(L10n.Common.previous), systemImage: "chevron.left")
            }
            .disabled((session.replayPly ?? session.record.moves.count) <= 0)
            Spacer()
            if session.isReplaying {
                Button(l10n(L10n.History.returnToLive)) { session.returnToLive() }.fontWeight(.semibold)
            } else {
                Text(L10n.History.livePosition, l10n).foregroundStyle(.secondary)
            }
            Spacer()
            Button { session.stepReplay(1) } label: {
                Label(l10n(L10n.Common.next), systemImage: "chevron.right").labelStyle(.titleAndIcon)
            }
            .disabled((session.replayPly ?? session.record.moves.count) >= session.record.moves.count)
        }
        .font(.subheadline).padding(16).background(.bar)
    }
}
