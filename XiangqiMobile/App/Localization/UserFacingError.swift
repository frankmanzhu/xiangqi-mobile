import Foundation
import os

/// A failure translated into something a player can read.
///
/// Thrown errors carry developer detail — FEN fragments, SQLite messages,
/// schema numbers — that is meaningless on screen and untranslatable. This maps
/// each failure to a catalog key and keeps the technical text for the log, so
/// nothing is lost to debugging.
struct UserFacingError: Equatable {
    let key: LocalizedKey
    /// Technical detail. Logged, never shown.
    let diagnostic: String

    private static let logger = Logger(
        subsystem: "com.frankzhu.xiangqi-mobile",
        category: "errors"
    )

    /// For a failure the app detects itself, where the right wording is already
    /// known and there is no thrown error to translate.
    init(_ key: LocalizedKey) {
        self.key = key
        self.diagnostic = key.key
    }

    init(_ error: any Error) {
        diagnostic = String(describing: error)
        key = Self.key(for: error)
        Self.logger.error("\(String(describing: error), privacy: .public)")
    }

    func text(_ l10n: Localizer) -> String { l10n(key) }

    private static func key(for error: any Error) -> LocalizedKey {
        switch error {
        case let error as CCPDLibraryError:
            switch error {
            case .databaseUnavailable: L10n.Error.Library.unavailable
            case .unsupportedSchema: L10n.Error.Library.unsupportedSchema
            case .corruptRecord: L10n.Error.Library.corruptRecord
            }
        case is CCPDCompressionError:
            L10n.Error.Library.corruptRecord
        case is LearningProgressError:
            L10n.Error.Progress.unsupportedSchema
        case is PositionError, is XiangqiPGNError:
            L10n.Error.Position.invalid
        case let error as PikafishError:
            switch error {
            case .networkMissing: L10n.Error.Engine.networkMissing
            case .networkInvalid: L10n.Error.Engine.networkInvalid
            case .invalidMove: L10n.Error.Engine.invalidMove
            case .initialization, .position, .search: L10n.Error.Engine.unavailable
            }
        case is CancellationError:
            // A cancelled search is the app's own doing, not a fault.
            L10n.Error.Engine.unavailable
        default:
            L10n.Error.generic
        }
    }
}
