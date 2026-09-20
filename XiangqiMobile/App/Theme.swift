import SwiftUI

struct BoardPalette {
    let background: Color
    let surface: Color
    let board: Color
    let line: Color
    let red: Color
    let black: Color
    let accent: Color
    let legal: Color
    let text: Color

    static func palette(for id: ThemeID) -> BoardPalette {
        switch id {
        case .classic:
            BoardPalette(
                background: Color(hex: 0xF6F0E4), surface: Color(hex: 0xFFF9EE),
                board: Color(hex: 0xE9CFA2), line: Color(hex: 0x604A35),
                red: Color(hex: 0xA8342C), black: Color(hex: 0x24221F),
                accent: Color(hex: 0xB23A2F), legal: Color(hex: 0x166B5C), text: Color(hex: 0x2B2620)
            )
        case .tournament:
            BoardPalette(
                background: Color(hex: 0x15181C), surface: Color(hex: 0x24282E),
                board: Color(hex: 0x30353A), line: Color(hex: 0xB8BDC3),
                red: Color(hex: 0xEE5B62), black: Color(hex: 0xE7EAEE),
                accent: Color(hex: 0xEE5B62), legal: Color(hex: 0x6DD5B2), text: .white
            )
        case .calm:
            BoardPalette(
                background: Color(hex: 0xF4F2EA), surface: Color(hex: 0xFFFEFA),
                board: Color(hex: 0xE5E0D2), line: Color(hex: 0x777064),
                red: Color(hex: 0xC54742), black: Color(hex: 0x263D38),
                accent: Color(hex: 0x236D60), legal: Color(hex: 0x247767), text: Color(hex: 0x193D35)
            )
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
