import SwiftUI

struct NewGameView: View {
    @EnvironmentObject private var app: AppModel
    let mode: GameMode
    @State private var sideChoice = "red"
    @State private var level = 2
    @State private var timeControl = TimeControl.casual
    @State private var confirmReplacement = false
    @AppStorage("theme") private var themeRaw = ThemeID.classic.rawValue

    private let levelNames = ["Beginner", "Club learner", "Club player", "Expert", "Master"]

    var body: some View {
        Form {
            Section {
                LabeledContent("Mode", value: mode.title)
            }
            if mode == .computer {
                Section("Your side") {
                    Picker("Your side", selection: $sideChoice) {
                        Text("Red").tag("red")
                        Text("Black").tag("black")
                        Text("Random").tag("random")
                    }.pickerStyle(.segmented)
                    Text("Red moves first.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Computer strength") {
                    Picker("Level", selection: $level) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }.pickerStyle(.segmented)
                    Text(levelNames[level - 1]).font(.headline)
                    Text(levelDescription).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Time") {
                Picker("Time", selection: $timeControl) {
                    ForEach(TimeControl.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section("Theme") {
                Picker("Theme", selection: $themeRaw) {
                    ForEach(ThemeID.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            }
            Section {
                Button {
                    if app.resumableRecord != nil { confirmReplacement = true }
                    else { Task { await start() } }
                } label: {
                    Text("Start game").font(.headline).frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("New game")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Replace the saved game?",
            isPresented: $confirmReplacement,
            titleVisibility: .visible
        ) {
            Button("Replace and start", role: .destructive) { Task { await start() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The current unfinished game will be replaced by this new game.")
        }
    }

    private var levelDescription: String {
        switch level {
        case 1: "Quick and forgiving; chooses among several sound moves."
        case 2: "A friendly opponent with credible tactics."
        case 3: "Consistent play for regular club players."
        case 4: "A focused opponent that looks further ahead."
        default: "The strongest built-in search setting."
        }
    }

    private func start() async {
        let humanSide: Side?
        if mode == .localTwoPlayer {
            humanSide = nil
        } else if sideChoice == "random" {
            humanSide = Bool.random() ? .red : .black
        } else {
            humanSide = sideChoice == "red" ? .red : .black
        }
        let selectedTheme = ThemeID(rawValue: themeRaw) ?? .classic
        let orientation = mode == .computer ? (humanSide ?? .red) : .red
        let record = GameRecord(
            mode: mode, humanSide: humanSide, computerLevel: level,
            timeControl: timeControl, orientation: orientation, theme: selectedTheme
        )
        await app.start(record)
    }
}
