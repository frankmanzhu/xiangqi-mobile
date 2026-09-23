import SwiftUI

extension EnvironmentValues {
    /// The active translator. Views read this instead of relying on `\.locale`,
    /// which does not redirect string lookup.
    @Entry public var l10n = Localizer(language: .system)
}

extension View {
    /// Installs `language` for both string lookup and locale-aware formatting.
    ///
    /// Deliberately no `.id(language)`: every view resolves its text through
    /// `\.l10n` while its body runs, so changing the environment value already
    /// re-renders them. Forcing a rebuild instead re-creates the
    /// `NavigationStack`, which resets its content to the top while the existing
    /// navigation bar keeps its collapsed state — drawing an inline title and an
    /// expanded large title at once, over the first row.
    func appLanguage(_ language: AppLanguage) -> some View {
        environment(\.l10n, Localizer(language: language))
            .environment(\.locale, language.locale)
    }
}

extension Text {
    /// A `Text` for a catalog key, resolved through `localizer`.
    init(_ key: LocalizedKey, _ localizer: Localizer) {
        self.init(verbatim: localizer(key))
    }

    init(_ key: LocalizedKey, _ localizer: Localizer, _ arguments: CVarArg...) {
        self.init(verbatim: localizer.format(key, arguments))
    }
}
