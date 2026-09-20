import SwiftUI

struct SettingsView: View {
    @AppStorage("theme") private var themeRaw = ThemeID.classic.rawValue
    @AppStorage("pieceLabels") private var pieceLabels = "Traditional"
    @AppStorage("coordinates") private var coordinates = "Red perspective"
    @AppStorage("confirmMoves") private var confirmMoves = false
    @AppStorage("sounds") private var sounds = true
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $themeRaw) {
                    ForEach(ThemeID.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Piece labels", selection: $pieceLabels) {
                    Text("Traditional Chinese").tag("Traditional")
                    Text("Simplified Chinese").tag("Simplified")
                }
                Picker("Coordinates", selection: $coordinates) {
                    Text("Off").tag("Off")
                    Text("Red perspective").tag("Red perspective")
                    Text("Always").tag("Always")
                }
            }
            Section("Interaction") {
                Toggle("Confirm moves", isOn: $confirmMoves)
                Toggle("Sound effects", isOn: $sounds)
                Toggle("Haptics", isOn: $haptics)
            }
            Section("Rules and records") {
                NavigationLink("How to play") { RulesHelpView() }
                LabeledContent("Move record", value: "UCI")
                LabeledContent("Rules policy", value: GameRecord.rulesPolicyID)
            }
            Section("About") {
                LabeledContent("Version", value: "1.0")
                LabeledContent("Computer", value: "Pikafish")
                Text("Computer play uses the bundled Pikafish engine and NNUE network entirely on-device. No account or network access is required.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

private struct RulesHelpView: View {
    var body: some View {
        List {
            Section("Goal") {
                Text("Checkmate the opposing general. Red moves first. A side with no legal move loses.")
            }
            Section("Pieces") {
                rule("Chariot", "Moves any distance along a clear file or rank.")
                rule("Horse", "Moves one orthogonal step then one diagonal step; the first step cannot be blocked.")
                rule("Cannon", "Moves like a chariot, but captures by jumping exactly one intervening piece.")
                rule("Elephant", "Moves two points diagonally, cannot jump, and cannot cross the river.")
                rule("Advisor", "Moves one point diagonally inside the palace.")
                rule("General", "Moves one point orthogonally inside the palace. The generals may not face on an open file.")
                rule("Soldier", "Moves forward one point. After crossing the river it may also move sideways, never backward.")
            }
            Section("Notation") {
                Text("Files are a–i and ranks are 0–9. A move such as b2e2 records its source and destination. The game stores the starting FEN plus this ordered move list for reliable replay and sharing.")
            }
        }
        .navigationTitle("Rules")
    }

    private func rule(_ name: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(name).font(.headline); Text(text).foregroundStyle(.secondary) }
    }
}
