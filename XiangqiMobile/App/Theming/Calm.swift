import SwiftUI

extension Theme {
    static let calm = Theme(
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
}
