import Foundation

/// Resolves `LocalizedKey` values against one specific language.
///
/// SwiftUI's `\.locale` environment value drives date and number formatting but
/// does not redirect string lookup, so an in-app language picker cannot work
/// through it alone. `Localizer` resolves against an explicitly chosen
/// `.lproj` bundle instead, which makes the selected language authoritative
/// regardless of the device's system language.
public struct Localizer: Sendable {
    public let locale: Locale
    private let bundle: Bundle

    public init(language: AppLanguage) {
        self.locale = language.locale
        self.bundle = language.bundle
    }

    /// The translated value, falling back to the compiled-in English source.
    public func callAsFunction(_ key: LocalizedKey) -> String {
        bundle.localizedString(forKey: key.key, value: key.en, table: nil)
    }

    public func callAsFunction(_ key: LocalizedKey, _ arguments: CVarArg...) -> String {
        format(key, arguments)
    }

    public func format(_ key: LocalizedKey, _ arguments: [CVarArg]) -> String {
        let template = callAsFunction(key)
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: locale, arguments: arguments)
    }
}

extension AppLanguage {
    /// The bundle holding this language's compiled strings.
    ///
    /// Falls back to the main bundle when the app was not built with the
    /// language, so lookups degrade to the English source values.
    var bundle: Bundle {
        guard let code = bundleLanguageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}
