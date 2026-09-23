import Foundation

/// A language the user can pick in Settings, independently of the device language.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese

    public static let storageKey = "appLanguage"

    public init(storedValue: String) {
        self = AppLanguage(rawValue: storedValue) ?? .system
    }

    /// Drives date, number, and list formatting.
    public var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english: Locale(identifier: "en")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .traditionalChinese: Locale(identifier: "zh-Hant")
        }
    }

    /// The `.lproj` directory to resolve strings from, or `nil` to follow the system.
    var bundleLanguageCode: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        case .traditionalChinese: "zh-Hant"
        }
    }

    var titleKey: LocalizedKey {
        switch self {
        case .system: L10n.Settings.Language.system
        case .english: L10n.Settings.Language.english
        case .simplifiedChinese: L10n.Settings.Language.simplifiedChinese
        case .traditionalChinese: L10n.Settings.Language.traditionalChinese
        }
    }
}
