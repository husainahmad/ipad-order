import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: 1.0)
    }
}

extension Color {
    // MARK: - Brand palette (warm coffee / latte — matches the Android POS)

    // Espresso primary
    static let posPrimary = Color(hex: 0x4E342E)
    static let posPrimaryDark = Color(hex: 0x36201A)
    static let posPrimaryLight = Color(hex: 0x8D6E63)
    static let posPrimaryContainer = Color(hex: 0xD7CCC8)
    static let posOnPrimaryContainer = Color(hex: 0x36201A)

    // Mocha secondary
    static let posSecondary = Color(hex: 0x795548)
    static let posSecondaryContainer = Color(hex: 0xE3D7D2)

    // Terracotta accent (CTAs, prices)
    static let posAccent = Color(hex: 0xBF360C)
    static let posAccentDark = Color(hex: 0x9E2F0B)
    static let posAccentSoft = Color(hex: 0xFFDBC8)

    // Warm neutrals & surfaces
    static let posSurface = Color(hex: 0xFFF8F5)
    static let posSurfaceContainer = Color(hex: 0xF9E9E2)
    static let posSurfaceContainerHigh = Color(hex: 0xF3E3DC)
    static let posSurfaceVariant = Color(hex: 0xF0E1DA)
    static let posTextPrimary = Color(hex: 0x221A17)
    static let posTextSecondary = Color(hex: 0x6E5D56)
    static let posDivider = Color(hex: 0xE0D0C8)
    static let posBgLight = Color(hex: 0xF6EAE3)
    static let posRowEven = Color(hex: 0xFFFFFF)
    static let posRowOdd = Color(hex: 0xF5E9E2)
    static let posCream = Color(hex: 0xFFF8F5)

    // Semantic states
    static let posStatusConfirmed = Color(hex: 0xB26A00)
    static let posStatusPaid = Color(hex: 0x2E7D32)
    static let posStatusVoid = Color(hex: 0xBA1A1A)
    static let posBlueAction = Color(hex: 0x00639B)
    static let posGrayButton = Color(hex: 0x83736B)
    static let posOutline = Color(hex: 0x83736C)
    static let posOutlineVariant = Color(hex: 0xD4C3BB)

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
