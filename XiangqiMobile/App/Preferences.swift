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

    /// `redPerspective` labels the board only while it is viewed from red's
    /// side, where file a is on the left and rank 0 at the bottom. Flipping the
    /// board reverses that frame, which is precisely when a player who wants
    /// only the familiar orientation would rather not read the labels.
    public func isVisible(orientation: Side) -> Bool {
        switch self {
        case .off: false
        case .redPerspective: orientation == .red
        case .always: true
        }
    }
}

/// A boolean setting with a default that applies until the user changes it.
///
/// `UserDefaults.bool(forKey:)` reports `false` for a key that was never
/// written, which would silently disable anything defaulting to on. Reading
/// through `object(forKey:)` keeps "unset" distinct from "off".
public struct BoolPreference: Sendable {
    public let key: String
    public let defaultValue: Bool

    public init(key: String, defaultValue: Bool) {
        self.key = key
        self.defaultValue = defaultValue
    }

    public var value: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }
}

/// The boolean settings, declared once so the view and the code that reacts to
/// them cannot disagree about a key or its default.
public enum GamePreference {
    public static let confirmMoves = BoolPreference(key: "confirmMoves", defaultValue: false)
    public static let sounds = BoolPreference(key: "sounds", defaultValue: true)
    public static let haptics = BoolPreference(key: "haptics", defaultValue: true)
}

/// Brings settings stored by earlier builds onto the current vocabulary.
public enum PreferenceMigration {
    /// Earlier builds stored these settings as their English display text
    /// ("Traditional", "Red perspective"). The pickers now tag options with
    /// stable tokens, and a stored value matching no tag leaves the picker with
    /// no selection, so normalize once at launch.
    public static func run(in defaults: UserDefaults = .standard) {
        normalize(PieceGlyphSet.storageKey, in: defaults) {
            PieceGlyphSet(storedValue: $0).rawValue
        }
        normalize(CoordinateDisplay.storageKey, in: defaults) {
            CoordinateDisplay(storedValue: $0).rawValue
        }
    }

    private static func normalize(
        _ key: String,
        in defaults: UserDefaults,
        using canonical: (String) -> String
    ) {
        guard let stored = defaults.string(forKey: key) else { return }
        let value = canonical(stored)
        guard value != stored else { return }
        defaults.set(value, forKey: key)
    }
}
