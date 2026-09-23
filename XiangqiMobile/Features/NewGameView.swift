import SwiftUI

struct NewGameView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.l10n) private var l10n
    let mode: GameMode
    @State private var sideChoice = SideChoice.red
    @State private var level = 2
    @State private var timeControl = TimeControl.casual
    @State private var confirmReplacement = false
    @AppStorage(ThemeID.storageKey) private var themeRaw = ThemeID.classic.rawValue

    private enum SideChoice: String, CaseIterable {
        case red, black, random

        var titleKey: LocalizedKey {
            switch self {
            case .red: L10n.Side.red
            case .black: L10n.Side.black
            case .random: L10n.Common.random
            }
        }

        var side: Side? {
            switch self {
            case .red: .red
            case .black: .black
            case .random: nil
            }
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(l10n(L10n.NewGame.mode), value: l10n(mode.titleKey))
            }
            if mode == .computer {
                Section(l10n(L10n.NewGame.Section.side)) {
                    Picker(l10n(L10n.NewGame.Section.side), selection: $sideChoice) {
                        ForEach(SideChoice.allCases, id: \.self) { choice in
                            Text(choice.titleKey, l10n).tag(choice)
                        }
                    }.pickerStyle(.segmented)
                    Text(L10n.NewGame.redMovesFirst, l10n).font(.footnote).foregroundStyle(.secondary)
                }
                Section(l10n(L10n.NewGame.Section.strength)) {
                    Picker(l10n(L10n.NewGame.level), selection: $level) {
                        ForEach(1...5, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                    }.pickerStyle(.segmented)
                    Text(levelName, l10n).font(.headline)
                    Text(levelDetail, l10n).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section(l10n(L10n.NewGame.Section.time)) {
                Picker(l10n(L10n.NewGame.Section.time), selection: $timeControl) {
                    ForEach(TimeControl.allCases, id: \.self) { Text($0.titleKey, l10n).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section(l10n(L10n.NewGame.Section.theme)) {
                ThemeChoiceStrip(selection: $themeRaw)
                    .padding(.vertical, 6)
            }
            Section {
                Button {
                    if app.resumableRecord != nil { confirmReplacement = true }
                    else { Task { await start() } }
                } label: {
                    Text(L10n.NewGame.start, l10n).font(.headline).frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(l10n(L10n.NewGame.title))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            l10n(L10n.NewGame.Replace.title),
            isPresented: $confirmReplacement,
            titleVisibility: .visible
        ) {
            Button(l10n(L10n.NewGame.Replace.confirm), role: .destructive) { Task { await start() } }
            Button(l10n(L10n.Common.cancel), role: .cancel) { }
        } message: {
            Text(L10n.NewGame.Replace.message, l10n)
        }
    }

    private var levelName: LocalizedKey {
        switch level {
        case 1: L10n.NewGame.LevelName._1
        case 2: L10n.NewGame.LevelName._2
        case 3: L10n.NewGame.LevelName._3
        case 4: L10n.NewGame.LevelName._4
        default: L10n.NewGame.LevelName._5
        }
    }

    private var levelDetail: LocalizedKey {
        switch level {
        case 1: L10n.NewGame.LevelDetail._1
        case 2: L10n.NewGame.LevelDetail._2
        case 3: L10n.NewGame.LevelDetail._3
        case 4: L10n.NewGame.LevelDetail._4
        default: L10n.NewGame.LevelDetail._5
        }
    }

    private func start() async {
        let humanSide: Side?
        if mode == .localTwoPlayer {
            humanSide = nil
        } else {
            humanSide = sideChoice.side ?? (Bool.random() ? .red : .black)
        }
        let orientation = mode == .computer ? (humanSide ?? .red) : .red
        let record = GameRecord(
            mode: mode,
            humanSide: humanSide,
            computerLevel: level,
            timeControl: timeControl,
            orientation: orientation,
            theme: ThemeID(themeRaw)
        )
        await app.start(record)
    }
}
