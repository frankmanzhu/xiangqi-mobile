import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    var body: some View {
        NavigationStack(path: $app.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .setup(let mode): NewGameView(mode: mode)
                    case .game:
                        if let session = app.session { GameView(session: session) }
                        else { ContentUnavailableView("Game unavailable", systemImage: "xmark.circle") }
                    case .settings: SettingsView()
                    case .learning: LearningHomeView()
                    case .learningCategory(let category): LearningLibraryView(category: category)
                    case .studyRecord(let id): CCPDStudyView(recordID: id)
                    case .practiceRecord(let id): CCPDPuzzleView(recordID: id)
                    }
                }
        }
        .environment(\.locale, appLanguage.locale)
        .tint(Color(hex: 0xA8342C))
        .alert("Saved game", isPresented: Binding(
            get: { app.recoveryMessage != nil },
            set: { if !$0 { app.recoveryMessage = nil } }
        )) {
            Button("OK", role: .cancel) { app.recoveryMessage = nil }
        } message: {
            Text(app.recoveryMessage ?? "")
        }
    }
}
