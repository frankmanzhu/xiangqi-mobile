import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @AppStorage(ThemeID.storageKey) private var themeRaw = ThemeID.classic.rawValue

    private var colors: ThemeColors { theme.colors }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
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
                Text(L10n.Home.title, l10n).font(.title.bold()).fontDesign(.serif)
                Text(L10n.Home.wordmark, l10n)
                    .font(.caption.weight(.semibold)).tracking(3).foregroundStyle(.secondary)
            }
            Spacer()
            Button { app.path.append(.settings) } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(colors.accent)
                    .frame(width: 44, height: 44)
                    .background(colors.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n(L10n.Common.settings))
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Home.Hero.title, l10n)
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
            Text(L10n.Home.Hero.subtitle, l10n)
                .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func continueCard(_ record: GameRecord) -> some View {
        Button { Task { await app.continueGame() } } label: {
            HStack(spacing: 16) {
                Image(systemName: "play.fill")
                    .font(.title2).foregroundStyle(colors.onAccent)
                    .frame(width: 52, height: 52).background(colors.accent, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Home.Continue.title, l10n).font(.headline)
                    Text(
                        L10n.Home.Continue.subtitle,
                        l10n,
                        l10n(record.mode.titleKey),
                        record.moves.count
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(18)
            .background(colors.surface, in: theme.cardShape(22))
            .overlay { theme.cardShape(22).stroke(theme.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityHint(l10n(L10n.Home.Continue.hint))
    }

    private var modeButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L10n.Home.Section.mode)
            modeButton(
                L10n.Mode.computer,
                subtitle: L10n.Home.Mode.Computer.subtitle,
                icon: "cpu",
                prominent: true
            ) { app.showSetup(.computer) }
            modeButton(
                L10n.Mode.localTwoPlayer,
                subtitle: L10n.Home.Mode.TwoPlayer.subtitle,
                icon: "person.2.fill"
            ) { app.showSetup(.localTwoPlayer) }
            modeButton(
                L10n.Home.Mode.Learn.title,
                subtitle: L10n.Home.Mode.Learn.subtitle,
                icon: "graduationcap.fill"
            ) { app.path.append(.learning) }
        }
    }

    private func modeButton(
        _ title: LocalizedKey,
        subtitle: LocalizedKey,
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
                    Text(title, l10n).font(.headline)
                    Text(subtitle, l10n).font(.caption).opacity(0.78)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).opacity(0.7)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(prominent ? colors.onAccent : colors.text)
            .background(prominent ? colors.accent : colors.surface, in: theme.cardShape())
            .overlay {
                theme.cardShape().stroke(prominent ? .clear : theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n(title))
        .accessibilityHint(l10n(subtitle))
    }

    private var themeStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L10n.Home.Section.theme)
            ThemeChoiceStrip(selection: $themeRaw)
        }
    }

    private func sectionLabel(_ key: LocalizedKey) -> some View {
        Text(key, l10n).font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(1.2)
    }
}
