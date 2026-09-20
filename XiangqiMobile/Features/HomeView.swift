import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage("theme") private var themeRaw = ThemeID.classic.rawValue
    private var theme: ThemeID { ThemeID(rawValue: themeRaw) ?? .classic }
    private var palette: BoardPalette { .palette(for: theme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    hero
                    if let record = app.resumableRecord { continueCard(record) }
                    modeButtons
                    themeStrip
                }
                .padding(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("象棋").font(.system(size: 32, weight: .bold, design: .serif))
                Text("XIANGQI").font(.caption.weight(.semibold)).tracking(3).foregroundStyle(.secondary)
            }
            Spacer()
            Button { app.path.append(.settings) } label: {
                Image(systemName: "gearshape").font(.title3).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The board is ready.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Play a thoughtful computer opponent, or pass the phone between two players. Everything works offline.")
                .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func continueCard(_ record: GameRecord) -> some View {
        Button { Task { await app.continueGame() } } label: {
            HStack(spacing: 16) {
                Image(systemName: "play.fill")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 52, height: 52).background(palette.accent, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue game").font(.headline)
                    Text("\(record.mode.title) · \(record.moves.count) moves")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(18).background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Returns to the saved position")
    }

    private var modeButtons: some View {
        VStack(spacing: 12) {
            primaryButton("Play computer", icon: "cpu") { app.showSetup(.computer) }
            primaryButton("Two players", icon: "person.2.fill") { app.showSetup(.localTwoPlayer) }
        }
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline).frame(maxWidth: .infinity).frame(height: 54)
                .foregroundStyle(.white).background(palette.accent, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var themeStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BOARD THEME").font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(1.2)
            HStack(spacing: 10) {
                ForEach(ThemeID.allCases, id: \.self) { candidate in
                    let colors = BoardPalette.palette(for: candidate)
                    Button { themeRaw = candidate.rawValue } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colors.board)
                                .overlay(Circle().fill(colors.red).padding(10))
                                .frame(height: 58)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme == candidate ? colors.accent : .clear, lineWidth: 3))
                            Text(candidate.title).font(.caption.weight(.medium)).foregroundStyle(palette.text)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
