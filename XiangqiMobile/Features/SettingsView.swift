import SwiftUI

struct SettingsView: View {
    @Environment(\.l10n) private var l10n
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(ThemeID.storageKey) private var themeRaw = ThemeID.classic.rawValue
    @AppStorage(PieceGlyphSet.storageKey) private var pieceLabelsRaw = PieceGlyphSet.traditional.rawValue
    @AppStorage(CoordinateDisplay.storageKey) private var coordinatesRaw = CoordinateDisplay.redPerspective.rawValue
    @AppStorage("confirmMoves") private var confirmMoves = false
    @AppStorage("sounds") private var sounds = true
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Form {
            Section(l10n(L10n.Settings.Section.language)) {
                Picker(l10n(L10n.Settings.appLanguage), selection: $languageRaw) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                        Text(language.titleKey, l10n).tag(language.rawValue)
                    }
                }
            }
            Section(l10n(L10n.Settings.Section.appearance)) {
                Picker(l10n(L10n.Settings.theme), selection: $themeRaw) {
                    ForEach(ThemeRegistry.themes) { theme in
                        Text(theme.nameKey, l10n).tag(theme.id.rawValue)
                    }
                }
                Picker(l10n(L10n.Settings.pieceLabels), selection: $pieceLabelsRaw) {
                    ForEach(PieceGlyphSet.allCases, id: \.rawValue) { option in
                        Text(option.titleKey, l10n).tag(option.rawValue)
                    }
                }
                Picker(l10n(L10n.Settings.coordinates), selection: $coordinatesRaw) {
                    ForEach(CoordinateDisplay.allCases, id: \.rawValue) { option in
                        Text(option.titleKey, l10n).tag(option.rawValue)
                    }
                }
            }
            Section(l10n(L10n.Settings.Section.interaction)) {
                Toggle(l10n(L10n.Settings.confirmMoves), isOn: $confirmMoves)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(l10n(L10n.Settings.sounds), isOn: $sounds)
                    Text(L10n.Settings.soundsPreviewHint, l10n)
                        .font(.caption).foregroundStyle(.secondary)
                }
                // Playing a cue on the way on lets the setting be judged here,
                // rather than by starting a game to find out how it sounds.
                .onChange(of: sounds) { _, isOn in
                    guard isOn else { return }
                    FeedbackPlayer.shared.prepare()
                    FeedbackPlayer.shared.play(.move)
                }
                Toggle(l10n(L10n.Settings.haptics), isOn: $haptics)
                    .onChange(of: haptics) { _, isOn in
                        guard isOn else { return }
                        FeedbackPlayer.shared.prepare()
                        FeedbackPlayer.shared.play(.capture)
                    }
            }
            Section(l10n(L10n.Settings.Section.rules)) {
                NavigationLink(l10n(L10n.Settings.howToPlay)) { RulesHelpView() }
                LabeledContent(l10n(L10n.Settings.moveRecord), value: "UCI")
                LabeledContent(l10n(L10n.Settings.rulesPolicy), value: l10n(L10n.Settings.rulesPolicyName))
                Text(L10n.Settings.rulesPolicyExplanation, l10n)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section(l10n(L10n.Settings.Section.about)) {
                LabeledContent(l10n(L10n.Settings.version), value: "1.0")
                LabeledContent(l10n(L10n.Settings.computer), value: "Pikafish")
                NavigationLink(l10n(L10n.Settings.licenses)) { LicensesView() }
                NavigationLink(l10n(L10n.Privacy.title)) { PrivacyPolicyView() }
                Link(
                    l10n(L10n.Settings.sourceCode),
                    destination: URL(string: "https://github.com/frankmanzhu/xiangqi-mobile")!
                )
                Link(
                    l10n(L10n.Settings.reportIssue),
                    destination: URL(string: "https://github.com/frankmanzhu/xiangqi-mobile/issues")!
                )
                Text(L10n.Settings.engineNote, l10n)
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .readableContentWidth()
        .navigationTitle(l10n(L10n.Settings.title))
    }
}

/// Bundled policy remains readable without opening a browser or going online.
private struct PrivacyPolicyView: View {
    @Environment(\.l10n) private var l10n

    var body: some View {
        List {
            Section {
                Text(L10n.Privacy.summary, l10n)
                Text(L10n.Privacy.updated, l10n).font(.footnote).foregroundStyle(.secondary)
            }
            Section(l10n(L10n.Privacy.Section.storage)) {
                Text(L10n.Privacy.storage, l10n)
            }
            Section(l10n(L10n.Privacy.Section.sharing)) {
                Text(L10n.Privacy.sharing, l10n)
            }
            Section(l10n(L10n.Privacy.Section.retention)) {
                Text(L10n.Privacy.retention, l10n)
            }
            Section(l10n(L10n.Privacy.Section.contact)) {
                Text(L10n.Privacy.contact, l10n)
                Link(l10n(L10n.Settings.reportIssue), destination: URL(string: "https://github.com/frankmanzhu/xiangqi-mobile/issues")!)
            }
        }
        .readableContentWidth()
        .navigationTitle(l10n(L10n.Privacy.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicensesView: View {
    @Environment(\.l10n) private var l10n

    var body: some View {
        List {
            Section(l10n(L10n.Licenses.Section.learning)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Licenses.Ccpd.name, l10n).font(.headline)
                    Text(L10n.Licenses.Ccpd.authors, l10n)
                    Text(L10n.Licenses.Ccpd.license, l10n)
                        .foregroundStyle(.secondary)
                    Text(L10n.Licenses.Ccpd.note, l10n)
                        .font(.footnote).foregroundStyle(.secondary)
                    Link(
                        l10n(L10n.Licenses.Ccpd.sourceLink),
                        destination: URL(string: "https://github.com/Yvonne761/Chinese-Chess-Practical-Dataset")!
                    )
                    Link(
                        l10n(L10n.Licenses.Ccpd.licenseLink),
                        destination: URL(string: "https://creativecommons.org/licenses/by/4.0/legalcode")!
                    )
                }
                if let notice = bundledText(named: "CCPD-CC-BY-4.0") {
                    DisclosureGroup(l10n(L10n.Licenses.bundledNotice)) {
                        Text(verbatim: notice).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
            Section(l10n(L10n.Licenses.Section.engine)) {
                Text(L10n.Licenses.Engine.note, l10n)
                    .font(.footnote).foregroundStyle(.secondary)
                Link(l10n(L10n.Licenses.Engine.source), destination: URL(string: "https://github.com/official-pikafish/Pikafish/tree/\(PikafishComputerClient.revision)")!)
                Text(L10n.Licenses.Engine.nnue, l10n)
                    .font(.footnote).foregroundStyle(.secondary)
                Link(l10n(L10n.Licenses.Engine.nnueTerms), destination: URL(string: "https://www.pikafish.com/list.html?lang=zh-CN")!)
                if let authors = bundledText(named: "Pikafish-AUTHORS") {
                    DisclosureGroup(l10n(L10n.Licenses.Engine.authors)) {
                        Text(verbatim: authors).font(.caption).textSelection(.enabled)
                    }
                }
                if let notice = bundledText(named: "Pikafish-NNUE-NOTICE") {
                    DisclosureGroup(l10n(L10n.Licenses.bundledNotice)) {
                        Text(verbatim: notice).font(.caption).textSelection(.enabled)
                    }
                }
                if let license = bundledText(named: "Pikafish-GPL-3.0") {
                    DisclosureGroup(l10n(L10n.Licenses.gpl)) {
                        Text(verbatim: license).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
        }
        .readableContentWidth()
        .navigationTitle(l10n(L10n.Licenses.title))
    }

    private func bundledText(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

private struct RulesHelpView: View {
    @Environment(\.l10n) private var l10n

    var body: some View {
        List {
            Section(l10n(L10n.Rules.Section.goal)) {
                Text(L10n.Rules.goal, l10n)
            }
            Section(l10n(L10n.Rules.Section.pieces)) {
                rule(L10n.Piece.chariot, L10n.Rules.chariot)
                rule(L10n.Piece.horse, L10n.Rules.horse)
                rule(L10n.Piece.cannon, L10n.Rules.cannon)
                rule(L10n.Piece.elephant, L10n.Rules.elephant)
                rule(L10n.Piece.advisor, L10n.Rules.advisor)
                rule(L10n.Piece.general, L10n.Rules.general)
                rule(L10n.Piece.soldier, L10n.Rules.soldier)
            }
            Section(l10n(L10n.Rules.Section.notation)) {
                Text(L10n.Rules.notation, l10n)
            }
        }
        .readableContentWidth()
        .navigationTitle(l10n(L10n.Rules.title))
    }

    private func rule(_ name: LocalizedKey, _ text: LocalizedKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name, l10n).font(.headline)
            Text(text, l10n).foregroundStyle(.secondary)
        }
    }
}
