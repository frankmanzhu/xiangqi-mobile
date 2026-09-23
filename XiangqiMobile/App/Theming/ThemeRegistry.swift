/// The set of themes the app can offer.
///
/// Built-in themes are registered at launch, each defined in its own file
/// (`Classic.swift`, `Tournament.swift`, `Calm.swift`) so designing one theme
/// never touches another's. `register(_:)` accepts further themes from
/// anywhere, so a new look is one `Theme` value in a new file — add the
/// `Theme` value as a `static let` on `Theme` and either list it in
/// `builtIn` below or call `ThemeRegistry.register(_:)` at launch — with no
/// `switch` to extend and no view to edit.
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

    nonisolated static let builtIn: [Theme] = [.classic, .tournament, .calm]
}
