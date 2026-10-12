import SwiftUI

enum ToastStyle {
    case success, error, info
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .success: return .posStatusPaid
        case .error: return .posStatusVoid
        case .info: return .posBlueAction
        }
    }
    var background: Color {
        switch self {
        case .success: return Color.posStatusPaid.opacity(0.12)
        case .error: return Color.posStatusVoid.opacity(0.12)
        case .info: return Color.posBlueAction.opacity(0.12)
        }
    }
}

struct AppToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}

final class ToastManager: ObservableObject {
    @Published var toast: AppToast?
    private var workItem: DispatchWorkItem?

    func show(_ message: String, style: ToastStyle = .error, duration: Double = 3.2) {
        workItem?.cancel()
        toast = AppToast(message: message, style: style)
        let item = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.22)) { self?.toast = nil }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    func dismiss() {
        workItem?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { toast = nil }
    }
}

struct ToastView: View {
    let toast: AppToast
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(toast.style.color)
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.posTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Button { } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.posTextSecondary)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.posSurface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(toast.style.color.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

struct ToastModifier: ViewModifier {
    @ObservedObject var manager: ToastManager
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let toast = manager.toast {
                ToastView(toast: toast)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                    .onTapGesture { manager.dismiss() }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: manager.toast)
    }
}

extension View {
    func toast(manager: ToastManager) -> some View {
        modifier(ToastModifier(manager: manager))
    }
}
