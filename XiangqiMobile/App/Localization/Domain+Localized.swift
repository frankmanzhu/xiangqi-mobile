import Foundation

/// Display names for domain values.
///
/// The domain types stay free of presentation: they expose `recordName` for the
/// portable record and nothing else, and the mapping to translated text lives
/// here, next to the catalog it draws from.
extension Side {
    var titleKey: LocalizedKey {
        switch self {
        case .red: L10n.Side.red
        case .black: L10n.Side.black
        }
    }
}

extension PieceKind {
    var titleKey: LocalizedKey {
        switch self {
        case .general: L10n.Piece.general
        case .advisor: L10n.Piece.advisor
        case .elephant: L10n.Piece.elephant
        case .horse: L10n.Piece.horse
        case .chariot: L10n.Piece.chariot
        case .cannon: L10n.Piece.cannon
        case .soldier: L10n.Piece.soldier
        }
    }
}

extension GameMode {
    var titleKey: LocalizedKey {
        switch self {
        case .computer: L10n.Mode.computer
        case .localTwoPlayer: L10n.Mode.localTwoPlayer
        }
    }
}

extension TimeControl {
    var titleKey: LocalizedKey {
        switch self {
        case .casual: L10n.TimeControl.casual
        case .tenMinutes: L10n.TimeControl.tenMinutes
        case .fifteenMinutes: L10n.TimeControl.fifteenMinutes
        }
    }
}

extension GameResultReason {
    var titleKey: LocalizedKey {
        switch self {
        case .checkmate: L10n.Reason.checkmate
        case .stalemate: L10n.Reason.stalemate
        case .resignation: L10n.Reason.resignation
        case .timeLoss: L10n.Reason.timeLoss
        case .repetition: L10n.Reason.repetition
        }
    }
}

extension GameStatus {
    func text(_ l10n: Localizer) -> String {
        switch self {
        case .win(let winner, let reason):
            l10n(L10n.Game.Status.wins, l10n(winner.titleKey), l10n(reason.titleKey))
        case .draw(let reason):
            l10n(L10n.Game.Status.draw, l10n(reason.titleKey))
        case .reviewing(let ply, let total):
            l10n(L10n.Game.Status.reviewing, ply, total)
        case .check(let side):
            l10n(L10n.Game.Status.check, l10n(side.titleKey))
        case .thinking:
            l10n(L10n.Game.Status.thinking)
        case .sideToMove(let side):
            l10n(L10n.Game.Status.sideToMove, l10n(side.titleKey))
        case .yourMove:
            l10n(L10n.Game.Status.yourMove)
        case .computerToMove:
            l10n(L10n.Game.Status.computerToMove)
        }
    }
}

extension GameMessage {
    func text(_ l10n: Localizer) -> String {
        switch self {
        case .engineMismatch: l10n(L10n.Game.Message.engineMismatch)
        case .notSaved: l10n(L10n.Game.Message.notSaved)
        case .failure(let failure): failure.text(l10n)
        }
    }
}
