import Foundation

/// A translatable string, identified by a stable semantic key.
///
/// Keys are declared in `Localizable.xcstrings` and surfaced as typed constants
/// in `Strings+Generated.swift`, so a view can never reference a key that the
/// catalog does not define. `en` is the compiled-in fallback used when a
/// language pack is missing an entry, which keeps the UI readable rather than
/// showing a raw key.
public struct LocalizedKey: Hashable, Sendable {
    public let key: String
    public let en: String
    /// Number of `%@`/`%lld` placeholders the value expects.
    public let arguments: Int

    public init(_ key: String, en: String, arguments: Int = 0) {
        self.key = key
        self.en = en
        self.arguments = arguments
    }
}
