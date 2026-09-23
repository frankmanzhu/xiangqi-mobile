import SwiftUI

/// The semantic colour roles a theme must supply.
///
/// Views name the role they need (`surface`, `accent`) rather than a literal
/// colour, so a new theme never requires touching a view.
public struct ThemeColors: Sendable {
    public let background: Color
    public let surface: Color
    public let board: Color
    public let line: Color
    public let river: Color
    public let red: Color
    public let black: Color
    public let accent: Color
    /// Content drawn on top of `accent`.
    public let onAccent: Color
    public let legal: Color
    public let text: Color
    public let textSecondary: Color

    public init(
        background: Color,
        surface: Color,
        board: Color,
        line: Color,
        river: Color,
        red: Color,
        black: Color,
        accent: Color,
        onAccent: Color = .white,
        legal: Color,
        text: Color,
        textSecondary: Color
    ) {
        self.background = background
        self.surface = surface
        self.board = board
        self.line = line
        self.river = river
        self.red = red
        self.black = black
        self.accent = accent
        self.onAccent = onAccent
        self.legal = legal
        self.text = text
        self.textSecondary = textSecondary
    }
}

/// Shape and line weights, so a theme can change its feel and not only its hues.
public struct ThemeMetrics: Sendable {
    public let boardCornerRadius: CGFloat
    public let cardCornerRadius: CGFloat
    public let controlCornerRadius: CGFloat
    public let gridLineWidth: CGFloat
    public let pieceStrokeWidth: CGFloat
    /// Piece diameter as a fraction of one grid step.
    public let pieceScale: CGFloat
    /// Opacity of the hairline that outlines cards and the board.
    public let borderOpacity: Double

    public init(
        boardCornerRadius: CGFloat = 16,
        cardCornerRadius: CGFloat = 18,
        controlCornerRadius: CGFloat = 12,
        gridLineWidth: CGFloat = 1.15,
        pieceStrokeWidth: CGFloat = 2,
        pieceScale: CGFloat = 0.82,
        borderOpacity: Double = 0.1
    ) {
        self.boardCornerRadius = boardCornerRadius
        self.cardCornerRadius = cardCornerRadius
        self.controlCornerRadius = controlCornerRadius
        self.gridLineWidth = gridLineWidth
        self.pieceStrokeWidth = pieceStrokeWidth
        self.pieceScale = pieceScale
        self.borderOpacity = borderOpacity
    }
}

/// A complete visual identity, addressed by a stable `ThemeID`.
///
/// Themes are values, not cases in a switch: adding one means constructing
/// another `Theme` and registering it, with no change to any view.
public struct Theme: Identifiable, Sendable {
    public let id: ThemeID
    public let nameKey: LocalizedKey
    public let colors: ThemeColors
    public let metrics: ThemeMetrics
    /// Forces light or dark system chrome, or `nil` to follow the device.
    public let colorScheme: ColorScheme?

    public init(
        id: ThemeID,
        nameKey: LocalizedKey,
        colors: ThemeColors,
        metrics: ThemeMetrics = ThemeMetrics(),
        colorScheme: ColorScheme? = nil
    ) {
        self.id = id
        self.nameKey = nameKey
        self.colors = colors
        self.metrics = metrics
        self.colorScheme = colorScheme
    }
}

extension Color {
    public init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
