import SwiftUI

extension Theme {
    static let tournament = Theme(
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
    )
}
