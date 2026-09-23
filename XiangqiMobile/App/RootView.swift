import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(ThemeID.storageKey) private var themeRaw = ThemeID.classic.rawValue

    private var language: AppLanguage { AppLanguage(storedValue: languageRaw) }
    private var theme: Theme { ThemeRegistry.theme(storedValue: themeRaw) }

    var body: some View {
        content
            .theme(theme)
            .appLanguage(language)
    }

    private var content: some View {
        NavigationStack(path: $app.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .setup(let mode): NewGameView(mode: mode)
                    case .game:
                        if let session = app.session { GameView(session: session) }
                        else { GameUnavailableView() }
                    case .settings: SettingsView()
                    case .learning: LearningHomeView()
                    case .learningCategory(let category): LearningLibraryView(category: category)
                    case .studyRecord(let id): CCPDStudyView(recordID: id)
                    case .practiceRecord(let id): CCPDPuzzleView(recordID: id)
                    }
                }
        }
        .modifier(RecoveryAlert(isPresented: $app.showRecoveryAlert))
    }
}

private struct RecoveryAlert: ViewModifier {
    @Environment(\.l10n) private var l10n
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert(
            l10n(L10n.App.Recovery.title),
            isPresented: $isPresented
        ) {
            Button(l10n(L10n.Common.ok), role: .cancel) { isPresented = false }
        } message: {
            Text(L10n.App.Recovery.message, l10n)
        }
    }
}

private struct GameUnavailableView: View {
    @Environment(\.l10n) private var l10n

    var body: some View {
        ContentUnavailableView(l10n(L10n.Game.unavailable), systemImage: "xmark.circle")
    }
}
