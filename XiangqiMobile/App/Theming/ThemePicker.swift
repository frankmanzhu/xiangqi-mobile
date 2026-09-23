import SwiftUI

/// A row of theme swatches, driven by whatever the registry holds.
struct ThemeChoiceStrip: View {
    @Environment(\.l10n) private var l10n
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ThemeRegistry.themes) { theme in
                let isSelected = selection == theme.id.rawValue
                Button {
                    selection = theme.id.rawValue
                } label: {
                    VStack(spacing: 8) {
                        MiniBoardPreview(theme: theme, selected: isSelected)
                        Text(theme.nameKey, l10n)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n(L10n.Theme.accessibilityLabel, l10n(theme.nameKey)))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private struct MiniBoardPreview: View {
    let theme: Theme
    let selected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                theme.cardShape(12).fill(theme.colors.board)

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
                    context.stroke(
                        path,
                        with: .color(theme.colors.line.opacity(0.45)),
                        lineWidth: 0.75
                    )
                }

                HStack(spacing: max(5, size.width * 0.05)) {
                    previewPiece("車", color: theme.colors.black)
                    previewPiece("帥", color: theme.colors.red)
                    previewPiece("炮", color: theme.colors.red)
                }
                .padding(.horizontal, 8)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colors.onAccent, theme.colors.accent)
                        .padding(5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .overlay {
                theme.cardShape(12).stroke(
                    selected ? theme.colors.accent : theme.border,
                    lineWidth: selected ? 2.5 : 1
                )
            }
        }
        .frame(height: 64)
    }

    private func previewPiece(_ glyph: String, color: Color) -> some View {
        Circle()
            .fill(theme.colors.surface)
            .overlay(Circle().stroke(color, lineWidth: theme.metrics.pieceStrokeWidth * 0.75))
            .overlay(
                Text(verbatim: glyph)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(color)
            )
            .aspectRatio(1, contentMode: .fit)
    }
}
