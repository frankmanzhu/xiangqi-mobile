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
                VStack(alignment: .leading, spacing: 26) {
                    header
                    hero
                    if let record = app.resumableRecord { continueCard(record) }
                    modeButtons
                    themeStrip
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("AppMark")
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("象棋").font(.title.bold()).fontDesign(.serif)
                Text("XIANGQI").font(.caption.weight(.semibold)).tracking(3).foregroundStyle(.secondary)
            }
            Spacer()
            Button { app.path.append(.settings) } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 44, height: 44)
                    .background(palette.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The board is ready.")
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
            Text("Play, study, and sharpen your game—entirely offline.")
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
            .padding(18)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.line.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Returns to the saved position")
    }

    private var modeButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("CHOOSE A MODE")
            modeButton("Play computer", subtitle: "Challenge Pikafish offline", icon: "cpu", prominent: true) {
                app.showSetup(.computer)
            }
            modeButton("Two players", subtitle: "Share this iPhone", icon: "person.2.fill") {
                app.showSetup(.localTwoPlayer)
            }
            modeButton("Learn and practice", subtitle: "Puzzles and master games", icon: "graduationcap.fill") {
                app.path.append(.learning)
            }
        }
    }

    private func modeButton(
        _ title: String,
        subtitle: String,
        icon: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).opacity(0.78)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).opacity(0.7)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(prominent ? Color.white : palette.text)
            .background(prominent ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(prominent ? Color.clear : palette.line.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    private var themeStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("BOARD THEME")
            ThemeChoiceStrip(selection: $themeRaw)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(1.2)
    }
}
