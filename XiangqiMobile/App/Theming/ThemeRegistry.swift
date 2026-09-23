import SwiftUI

/// The set of themes the app can offer.
///
/// Built-in themes are registered at launch. `register(_:)` accepts further
/// themes from anywhere, so a new look is one `Theme` value and one call —
/// no `switch` to extend and no view to edit.
@MainActor
public enum ThemeRegistry {
    private static var storage: [Theme] = builtIn

    /// Every registered theme, in registration order.
    public static var themes: [Theme] { storage }

    /// The theme used before any selection is read, and when a requested id is
    /// unknown. Available off the main actor so it can seed the environment.
    public nonisolated static var initial: Theme { builtIn[0] }

    public static var fallback: Theme { storage.first ?? initial }

    /// Registers a theme, replacing any earlier theme with the same id.
    public static func register(_ theme: Theme) {
        if let index = storage.firstIndex(where: { $0.id == theme.id }) {
            storage[index] = theme
        } else {
            storage.append(theme)
        }
    }

    /// The theme for `id`, or the fallback when it is not registered — a saved
    /// game that names a theme this build no longer ships still opens.
    public static func theme(_ id: ThemeID) -> Theme {
        storage.first { $0.id == id } ?? fallback
    }

    public static func theme(storedValue: String) -> Theme {
        theme(ThemeID(storedValue))
    }

    nonisolated static let builtIn: [Theme] = [
        Theme(
            id: .classic,
            nameKey: L10n.Theme.classic,
            colors: ThemeColors(
                background: Color(hex: 0xF6F0E4),
                surface: Color(hex: 0xFFF9EE),
                board: Color(hex: 0xE9CFA2),
                line: Color(hex: 0x604A35),
                river: Color(hex: 0x604A35, alpha: 0.72),
                red: Color(hex: 0xA8342C),
                black: Color(hex: 0x24221F),
                accent: Color(hex: 0xB23A2F),
                legal: Color(hex: 0x166B5C),
                text: Color(hex: 0x2B2620),
                textSecondary: Color(hex: 0x2B2620, alpha: 0.62)
            ),
            colorScheme: .light
        ),
        Theme(
            id: .tournament,
            nameKey: L10n.Theme.tournament,
            colors: ThemeColors(
                background: Color(hex: 0x15181C),
                surface: Color(hex: 0x24282E),
                board: Color(hex: 0x30353A),
                line: Color(hex: 0xB8BDC3),
                river: Color(hex: 0xB8BDC3, alpha: 0.72),
                red: Color(hex: 0xEE5B62),
                black: Color(hex: 0xE7EAEE),
                accent: Color(hex: 0xEE5B62),
                legal: Color(hex: 0x6DD5B2),
                text: .white,
                textSecondary: Color(hex: 0xB8BDC3)
            ),
            metrics: ThemeMetrics(
                boardCornerRadius: 12,
                cardCornerRadius: 14,
                controlCornerRadius: 10,
                gridLineWidth: 1,
                borderOpacity: 0.18
            ),
            colorScheme: .dark
        ),
        Theme(
            id: .calm,
            nameKey: L10n.Theme.calm,
            colors: ThemeColors(
                background: Color(hex: 0xF4F2EA),
                surface: Color(hex: 0xFFFEFA),
                board: Color(hex: 0xE5E0D2),
                line: Color(hex: 0x777064),
                river: Color(hex: 0x777064, alpha: 0.72),
                red: Color(hex: 0xC54742),
                black: Color(hex: 0x263D38),
                accent: Color(hex: 0x236D60),
                legal: Color(hex: 0x247767),
                text: Color(hex: 0x193D35),
                textSecondary: Color(hex: 0x193D35, alpha: 0.6)
            ),
            metrics: ThemeMetrics(
                boardCornerRadius: 22,
                cardCornerRadius: 22,
                controlCornerRadius: 16,
                gridLineWidth: 1,
                pieceStrokeWidth: 1.5,
                borderOpacity: 0.08
            ),
            colorScheme: .light
        )
    ]
}
