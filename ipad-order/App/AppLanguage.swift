import Foundation
import SwiftUI

/// The app's UI language.
///
/// The device locale is not a reliable answer for a shop till: the tablet is often
/// left in English while the staff read Indonesian. This stores an explicit choice
/// and exposes the locale SwiftUI uses for `Text("...")` lookups, so every screen
/// and the receipt share one language.
enum AppLanguage {

    static let system = "system"
    static let english = "en"
    static let indonesian = "id"

    private static let key = "app_language"

    /// Language codes offered by the settings screen, in display order.
    static let codes = [english, indonesian]

    static var current: String {
        get {
            let stored = UserDefaults.standard.string(forKey: key) ?? system
            if stored == system { return system }
            return codes.contains(stored) ? stored : system
        }
        set {
            let value = (newValue == system || codes.contains(newValue)) ? newValue : system
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    /// The concrete language code, resolving "system" to the device language.
    static var resolvedCode: String {
        if current != system { return current }
        let device = Locale.preferredLanguages.first ?? "en"
        if device.hasPrefix("id") { return indonesian }
        if device.hasPrefix("in") { return indonesian }
        return english
    }

    /// Locale for SwiftUI's `Text("...")` lookups.
    static var locale: Locale {
        Locale(identifier: resolvedCode)
    }
}
