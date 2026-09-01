import Foundation
import UIKit
import CoreText

enum FontLoader {
    static func registerFonts() {
        let fontNames = [
            "NotoSansJP-Regular",
            "NotoSansJP-Medium",
            "NotoSansJP-Bold",
            "NotoSansSC-Regular",
            "NotoSansKR-Regular",
            "NotoSansArabic-Regular"
        ]

        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                 ?? Bundle.main.url(forResource: name, withExtension: "otf") else {
                print("[FontLoader] Font not found in bundle: \(name)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                if let err = error?.takeRetainedValue() {
                    print("[FontLoader] Failed to register \(name): \(err)")
                }
            } else {
                print("[FontLoader] Registered: \(name)")
            }
        }
    }

    static func font(for language: String, weight: UIFont.Weight = .regular, size: CGFloat) -> UIFont {
        // Try bundled Noto first, fallback to iPad-native CJK/Arabic fonts that contain glyphs
        // System font (SF) has no CJK, so must use Hiragino/PingFang/AppleSD/Geeza
        let candidates: [String]
        switch language {
        case "ja":
            candidates = (weight == .bold ? ["NotoSansJP-Bold", "HiraginoSans-W6", "HiraginoSans-W3"] :
                         weight == .medium ? ["NotoSansJP-Medium", "HiraginoSans-W6", "HiraginoSans-W3"] :
                         ["NotoSansJP-Regular", "HiraginoSans-W3", "HiraginoSans-W6"])
        case "zh-Hans", "zh-Hant":
            candidates = ["NotoSansSC-Regular", "PingFangSC-Regular", "PingFangSC-Medium", "Heiti SC"]
        case "ko":
            candidates = ["NotoSansKR-Regular", "AppleSDGothicNeo-Regular", "AppleSDGothicNeo-Medium"]
        case "ar":
            candidates = ["NotoSansArabic-Regular", "GeezaPro", "GeezaPro-Bold"]
        case "th":
            candidates = ["Thonburi", "SukhumvitSet-Text"]
        default:
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        for name in candidates {
            if let f = UIFont(name: name, size: size) { return f }
        }
        // Last resort: system font (will fallback via cascade but warn)
        print("[FontLoader] No font found for \(language), falling back to system")
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}