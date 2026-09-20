import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        case .traditionalChinese:
            Locale(identifier: "zh-Hant")
        }
    }
}
