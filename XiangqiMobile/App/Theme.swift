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

struct ThemeChoiceStrip: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ThemeID.allCases, id: \.self) { theme in
                let palette = BoardPalette.palette(for: theme)
                Button {
                    selection = theme.rawValue
                } label: {
                    VStack(spacing: 8) {
                        MiniBoardPreview(palette: palette, selected: selection == theme.rawValue)
                        Text(theme.title)
                            .font(.caption.weight(selection == theme.rawValue ? .semibold : .regular))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.title) theme")
                .accessibilityAddTraits(selection == theme.rawValue ? .isSelected : [])
            }
        }
    }
}

private struct MiniBoardPreview: View {
    let palette: BoardPalette
    let selected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.board)

                Canvas { context, _ in
                    var path = Path()
                    for fraction in [0.25, 0.5, 0.75] {
                        path.move(to: CGPoint(x: size.width * fraction, y: 8))
                        path.addLine(to: CGPoint(x: size.width * fraction, y: size.height - 8))
                    }
                    for fraction in [0.34, 0.66] {
                        path.move(to: CGPoint(x: 8, y: size.height * fraction))
                        path.addLine(to: CGPoint(x: size.width - 8, y: size.height * fraction))
                    }
                    context.stroke(path, with: .color(palette.line.opacity(0.45)), lineWidth: 0.75)
                }

                HStack(spacing: max(5, size.width * 0.05)) {
                    previewPiece("車", color: palette.black)
                    previewPiece("帥", color: palette.red)
                    previewPiece("炮", color: palette.red)
                }
                .padding(.horizontal, 8)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white, palette.accent)
                        .padding(5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? palette.accent : palette.line.opacity(0.16), lineWidth: selected ? 2.5 : 1)
            }
        }
        .frame(height: 64)
    }

    private func previewPiece(_ glyph: String, color: Color) -> some View {
        Circle()
            .fill(palette.surface)
            .overlay(Circle().stroke(color, lineWidth: 1.5))
            .overlay(Text(glyph).font(.system(size: 13, weight: .bold, design: .serif)).foregroundStyle(color))
            .aspectRatio(1, contentMode: .fit)
    }
}
