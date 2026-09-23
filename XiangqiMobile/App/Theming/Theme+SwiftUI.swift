import SwiftUI

extension EnvironmentValues {
    /// The active theme. Views read this rather than re-reading `@AppStorage`,
    /// so the selection has one source of truth.
    @Entry public var theme = ThemeRegistry.initial
}

extension View {
    /// Installs `theme` and the system chrome that goes with it.
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
            .tint(theme.colors.accent)
            .preferredColorScheme(theme.colorScheme)
    }
}

extension Theme {
    /// The rounded rectangle used for cards and docks in this theme.
    func cardShape(_ radius: CGFloat? = nil) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius ?? metrics.cardCornerRadius, style: .continuous)
    }

    var boardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.boardCornerRadius, style: .continuous)
    }

    var controlShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.controlCornerRadius, style: .continuous)
    }

    /// The hairline colour used to outline surfaces against the background.
    var border: Color { colors.line.opacity(metrics.borderOpacity) }
}
