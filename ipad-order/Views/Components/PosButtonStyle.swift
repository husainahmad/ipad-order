import SwiftUI

struct PosButtonStyle: ButtonStyle {
    let filled: Bool
    var outlineColor: Color = .posGrayButton
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(filled ? .white : .posTextPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(filled ? AnyShapeStyle(Color.posAccentGradient) : AnyShapeStyle(Color.posSurfaceContainerHigh))
            .overlay(RoundedRectangle(cornerRadius: PosShape.cornerMedium).stroke(filled ? Color.clear : outlineColor, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
            .shadow(color: filled ? Color.posAccent.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}