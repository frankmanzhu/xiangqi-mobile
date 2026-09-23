import SwiftUI

extension Theme {
    static let classic = Theme(
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
    )
}
