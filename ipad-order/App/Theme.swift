import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: 1.0)
    }

    /// Adaptive color: light hex on light mode, dark hex on dark mode
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    /// Current app theme (for cafe override). Reads UserDefaults directly so Color statics react without environment.
    private static var appTheme: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "light") ?? .light
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                  green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(hex & 0xFF) / 255.0,
                  alpha: 1.0)
    }
}

extension Color {
    // MARK: - Brand palette (warm coffee / latte — matches the Android POS)
    // Light / Dark via adaptive, Cafe via fixed warm Harmoni palette

    static var posPrimary: Color {
        if appTheme == .cafe { return Color(hex: 0x5D4037) }
        return .adaptive(light: 0x4E342E, dark: 0x6D4C41)
    }
    static var posPrimaryDark: Color {
        if appTheme == .cafe { return Color(hex: 0x3E2723) }
        return .adaptive(light: 0x36201A, dark: 0x4E342E)
    }
    static var posPrimaryLight: Color {
        if appTheme == .cafe { return Color(hex: 0x8D6E63) }
        return .adaptive(light: 0x8D6E63, dark: 0xA1887F)
    }
    static var posPrimaryContainer: Color {
        if appTheme == .cafe { return Color(hex: 0xEFEBE9) }
        return .adaptive(light: 0xD7CCC8, dark: 0x3E2F2B)
    }
    static var posOnPrimaryContainer: Color {
        if appTheme == .cafe { return Color(hex: 0x3E2723) }
        return .adaptive(light: 0x36201A, dark: 0xEFEBE9)
    }

    // Mocha secondary
    static var posSecondary: Color {
        if appTheme == .cafe { return Color(hex: 0x6D4C41) }
        return .adaptive(light: 0x795548, dark: 0x8D6E63)
    }
    static var posSecondaryContainer: Color {
        if appTheme == .cafe { return Color(hex: 0xD7CCC8) }
        return .adaptive(light: 0xE3D7D2, dark: 0x3A2E2A)
    }

    // Terracotta accent (CTAs, prices) — cafe keeps terracotta but richer
    static var posAccent: Color {
        if appTheme == .cafe { return Color(hex: 0xBF360C) }
        return .adaptive(light: 0xBF360C, dark: 0xFF7043)
    }
    static var posAccentDark: Color {
        if appTheme == .cafe { return Color(hex: 0x8D2E0B) }
        return .adaptive(light: 0x9E2F0B, dark: 0xE64A19)
    }
    static var posAccentSoft: Color {
        if appTheme == .cafe { return Color(hex: 0xFFCCBC) }
        return .adaptive(light: 0xFFDBC8, dark: 0x3E2A22)
    }

    // Warm neutrals & surfaces — cafe is creamy latte (distinct from light/dark)
    static var posSurface: Color {
        if appTheme == .cafe { return Color(hex: 0xFDF6F0) }
        return .adaptive(light: 0xFFF8F5, dark: 0x1E1917)
    }
    static var posSurfaceContainer: Color {
        if appTheme == .cafe { return Color(hex: 0xF5E9E0) }
        return .adaptive(light: 0xF9E9E2, dark: 0x2B2220)
    }
    static var posSurfaceContainerHigh: Color {
        if appTheme == .cafe { return Color(hex: 0xEFDECD) }
        return .adaptive(light: 0xF3E3DC, dark: 0x332B28)
    }
    static var posSurfaceVariant: Color {
        if appTheme == .cafe { return Color(hex: 0xE6D5C3) }
        return .adaptive(light: 0xF0E1DA, dark: 0x3A2F2B)
    }
    static var posTextPrimary: Color {
        if appTheme == .cafe { return Color(hex: 0x3E2723) }
        return .adaptive(light: 0x221A17, dark: 0xF5E9E2)
    }
    static var posTextSecondary: Color {
        if appTheme == .cafe { return Color(hex: 0x6D4C41) }
        return .adaptive(light: 0x6E5D56, dark: 0xC4B5B0)
    }
    static var posDivider: Color {
        if appTheme == .cafe { return Color(hex: 0xBCAAA4) }
        return .adaptive(light: 0xE0D0C8, dark: 0x4A3C37)
    }
    static var posBgLight: Color {
        if appTheme == .cafe { return Color(hex: 0xFDF2E9) }
        return .adaptive(light: 0xF6EAE3, dark: 0x1C1513)
    }
    static var posRowEven: Color {
        if appTheme == .cafe { return Color(hex: 0xFFFBF5) }
        return .adaptive(light: 0xFFFFFF, dark: 0x2A2220)
    }
    static var posRowOdd: Color {
        if appTheme == .cafe { return Color(hex: 0xF5E9E0) }
        return .adaptive(light: 0xF5E9E2, dark: 0x241E1C)
    }
    static var posCream: Color {
        if appTheme == .cafe { return Color(hex: 0xFDF6F0) }
        return .adaptive(light: 0xFFF8F5, dark: 0x1E1917)
    }

    // Semantic states
    static var posStatusConfirmed: Color {
        if appTheme == .cafe { return Color(hex: 0xB26A00) }
        return .adaptive(light: 0xB26A00, dark: 0xFFB74D)
    }
    static var posStatusPaid: Color {
        if appTheme == .cafe { return Color(hex: 0x2E7D32) }
        return .adaptive(light: 0x2E7D32, dark: 0x81C784)
    }
    static var posStatusVoid: Color {
        if appTheme == .cafe { return Color(hex: 0xBA1A1A) }
        return .adaptive(light: 0xBA1A1A, dark: 0xEF5350)
    }
    static var posBlueAction: Color {
        if appTheme == .cafe { return Color(hex: 0x00695C) }
        return .adaptive(light: 0x00639B, dark: 0x4FC3F7)
    }
    static var posGrayButton: Color {
        if appTheme == .cafe { return Color(hex: 0x795548) }
        return .adaptive(light: 0x83736B, dark: 0x9A8A82)
    }
    static var posOutline: Color {
        if appTheme == .cafe { return Color(hex: 0x8D6E63) }
        return .adaptive(light: 0x83736C, dark: 0x8A7A73)
    }
    static var posOutlineVariant: Color {
        if appTheme == .cafe { return Color(hex: 0xD7CCC8) }
        return .adaptive(light: 0xD4C3BB, dark: 0x5A4A44)
    }

    // MARK: - Gradients

    static var posPrimaryGradient: LinearGradient {
        LinearGradient(colors: [Color.posPrimary, Color.posPrimaryDark],
                       startPoint: .top,
                       endPoint: .bottom)
    }

    static var posAccentGradient: LinearGradient {
        LinearGradient(colors: [Color.posAccent, Color.posAccentDark],
                       startPoint: .top,
                       endPoint: .bottom)
    }

    static var posLoginGradient: LinearGradient {
        LinearGradient(colors: [Color.posPrimaryLight, Color.posPrimary, Color.posPrimaryDark],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}

// MARK: - Design tokens

enum PosShape {
    static let cornerSmall: CGFloat = 8
    static let cornerMedium: CGFloat = 12
    static let cornerLarge: CGFloat = 16
    static let cornerExtraLarge: CGFloat = 28
    static let cornerFull: CGFloat = 100
}

enum PosSpacing {
    static let xsmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

// MARK: - Reusable card / panel modifiers

struct PosCardStyle: ViewModifier {
    var cornerRadius: CGFloat = PosShape.cornerLarge
    var padding: CGFloat = PosSpacing.medium
    var shadow: Bool = true
    var fill: Color = .posSurfaceContainerHigh

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.posOutlineVariant.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(shadow ? 0.06 : 0), radius: shadow ? 8 : 0, x: 0, y: 2)
    }
}

extension View {
    func posCard(cornerRadius: CGFloat = PosShape.cornerLarge,
                 padding: CGFloat = PosSpacing.medium,
                 shadow: Bool = true,
                 fill: Color = .posSurfaceContainerHigh) -> some View {
        modifier(PosCardStyle(cornerRadius: cornerRadius, padding: padding, shadow: shadow, fill: fill))
    }

    func posSectionHeader(_ title: String, color: Color = .posAccent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 18)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.posTextPrimary)
            Spacer()
        }
    }

    /// Standard POS toolbar header with espresso gradient
    func posToolbarHeader(icon: String, title: String, trailing: (() -> AnyView)? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.92))
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            if let trailing = trailing { trailing() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.posPrimaryGradient)
        .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
    }

    /// Rounded "Back" pill shown on toolbar headers
    var posBackButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left")
            Text("Back")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.15))
        .clipShape(Capsule())
    }

    func posFade(_ value: Bool) -> some View {
        self.opacity(value ? 1 : 0)
    }
}

// MARK: - Theme mode (light default, cafe for Coffee & Restaurant POS)

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    case cafe = "cafe"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        case .cafe: return "Café"
        }
    }

    var description: String {
        switch self {
        case .light: return "Clean"
        case .dark: return "Espresso"
        case .system: return "Auto"
        case .cafe: return "Harmoni"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        case .cafe: return "cup.and.saucer.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        case .cafe: return .light // cafe is warm light, forces light chrome
        }
    }
}

final class ThemeManager: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
            // Force Color statics to re-evaluate via objectWillChange already fired
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "appTheme")
        if let stored, let t = AppTheme(rawValue: stored) {
            theme = t
        } else {
            // Default is light mode per requirement
            theme = .light
        }
    }

    var colorScheme: ColorScheme? { theme.colorScheme }
}
