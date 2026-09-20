import Foundation
import SwiftUI

enum AppRoute: Hashable {
    case setup(GameMode)
    case game
    case settings
}

@MainActor
final class AppModel: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var resumableRecord: GameRecord?
    @Published var session: GameSession?
    @Published var recoveryMessage: String?

    let repository = GameRepository()

    func loadSavedGame() async {
        do {
            if ProcessInfo.processInfo.arguments.contains("-resetTestData") {
                try await repository.delete()
            }
            let record = try await repository.load()
            resumableRecord = record?.isActive == true ? record : nil
        } catch {
            recoveryMessage = "The saved game could not be validated. Its file has been preserved."
        }
    }

    func showSetup(_ mode: GameMode) {
        path.append(.setup(mode))
    }

    func start(_ record: GameRecord) async {
        do { try await repository.save(record) } catch { }
        let game = GameSession(record: record, repository: repository)
        session = game
        resumableRecord = record
        path.append(.game)
        await game.startIfNeeded()
    }

    func continueGame() async {
        guard let record = resumableRecord else { return }
        let game = GameSession(record: record, repository: repository)
        session = game
        path.append(.game)
        await game.startIfNeeded()
    }

    func leaveGame() {
        let leavingSession = session
        if let leavingSession, leavingSession.record.isActive { resumableRecord = leavingSession.record }
        Task { await leavingSession?.pause() }
        self.session = nil
        path.removeAll()
    }

    func newGameFromGame(_ mode: GameMode) {
        session?.cancelSearch()
        session = nil
        path = [.setup(mode)]
    }
}
