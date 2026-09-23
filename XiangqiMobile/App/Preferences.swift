import SwiftUI

/// Which character set the piece glyphs use.
///
/// Stored as a stable token rather than its own display text, so the label can
/// be translated or reworded without invalidating what users already saved.
public enum PieceGlyphSet: String, CaseIterable, Sendable {
    case traditional
    case simplified

    public static let storageKey = "pieceLabels"

    public init(storedValue: String) {
        // Builds before the typed preferences stored the English label itself.
        switch storedValue.lowercased() {
        case "simplified": self = .simplified
        default: self = .traditional
        }
    }

    var titleKey: LocalizedKey {
        switch self {
        case .traditional: L10n.Settings.PieceLabelsOption.traditional
        case .simplified: L10n.Settings.PieceLabelsOption.simplified
        }
    }

    public func glyph(for piece: Piece) -> String {
        switch self {
        case .simplified:
            switch (piece.side, piece.kind) {
            case (.red, .general): "帅"
            case (.black, .general): "将"
            case (.red, .advisor): "仕"
            case (.black, .advisor): "士"
            case (.red, .elephant): "相"
            case (.black, .elephant): "象"
            case (_, .horse): "马"
            case (_, .chariot): "车"
            case (_, .cannon): "炮"
            case (.red, .soldier): "兵"
            case (.black, .soldier): "卒"
            }
        case .traditional:
            switch (piece.side, piece.kind) {
            case (.red, .general): "帥"
            case (.black, .general): "將"
            case (.red, .advisor): "仕"
            case (.black, .advisor): "士"
            case (.red, .elephant): "相"
            case (.black, .elephant): "象"
            case (_, .horse): "馬"
            case (_, .chariot): "車"
            case (_, .cannon): "炮"
            case (.red, .soldier): "兵"
            case (.black, .soldier): "卒"
            }
        }
    }
}

/// When file and rank labels are drawn around the board.
public enum CoordinateDisplay: String, CaseIterable, Sendable {
    case off
    case redPerspective
    case always

    public static let storageKey = "coordinates"

    public init(storedValue: String) {
        // Builds before the typed preferences stored the English label itself.
        switch storedValue.lowercased() {
        case "off": self = .off
        case "always": self = .always
        default: self = .redPerspective
        }
    }

    var titleKey: LocalizedKey {
        switch self {
        case .off: L10n.Common.off
        case .redPerspective: L10n.Settings.CoordinatesOption.redPerspective
        case .always: L10n.Common.always
        }
    }
}
