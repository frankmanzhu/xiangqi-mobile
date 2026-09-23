import SwiftUI

extension EnvironmentValues {
    /// The active translator. Views read this instead of relying on `\.locale`,
    /// which does not redirect string lookup.
    @Entry public var l10n = Localizer(language: .system)
}

extension View {
    /// Installs `language` for both string lookup and locale-aware formatting.
    ///
    /// The `id` forces SwiftUI to rebuild the hierarchy, which is what refreshes
    /// navigation titles, toolbars, and other cached chrome on a language change.
    func appLanguage(_ language: AppLanguage) -> some View {
        environment(\.l10n, Localizer(language: language))
            .environment(\.locale, language.locale)
            .id(language)
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
