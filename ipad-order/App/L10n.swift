import Foundation

/// Runtime localization helper for strings that are not literal `LocalizedStringKey`s
/// (status messages, values built in view models, enum display names, etc.).
///
/// Literal `Text("...")` / `Button("...")` already localize through SwiftUI's
/// `LocalizedStringKey`. Use this for everything that is assembled as a `String` at
/// runtime so the app-selected language still applies.
enum L10n {

    /// Localizes a key using the app-selected language (falls back to the key itself).
    static func t(_ key: String) -> String {
        PrintUtils.localized(key, lang: AppLanguage.resolvedCode)
    }

    /// Localizes a format key and substitutes the arguments, e.g.
    /// `L10n.t("Print failed: %@", error.localizedDescription)`.
    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: AppLanguage.locale, arguments: args)
    }
}
