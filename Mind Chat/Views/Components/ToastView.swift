import SwiftUI
import Combine

// MARK: - Toast Model

struct Toast: Identifiable, Sendable {
    let id    = UUID()
    let message: String
    let type: ToastType
    var action: (@Sendable () -> Void)?
    var actionLabel: String?

    enum ToastType: Sendable { case success, error, info }
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {

    static let shared = ToastManager()
    @Published var toasts: [Toast] = []
    private init() {}

    func show(_ toast: Toast, timeout: Double = 3.5) {
        if toasts.count >= 3 { toasts.removeFirst() }
        toasts.append(toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            self.toasts.removeAll { $0.id == toast.id }
        }
    }

    func success(_ msg: String, action: (@Sendable () -> Void)? = nil, actionLabel: String? = nil) {
        show(Toast(message: msg, type: .success, action: action, actionLabel: actionLabel))
    }

    func error(_ msg: String) { show(Toast(message: msg, type: .error)) }

    func info(_ msg: String, action: (@Sendable () -> Void)? = nil, actionLabel: String? = nil, timeout: Double = 3.5) {
        show(Toast(message: msg, type: .info, action: action, actionLabel: actionLabel), timeout: timeout)
    }
}

// MARK: - Toast Row

struct ToastRow: View {

    let toast: Toast
    let onDismiss: () -> Void

    var icon: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        switch toast.type {
        case .success: return Color.accentGreen
        case .error:   return Color.accentRed
        case .info:    return Color.mcTextLink
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(toast.message).font(.subheadline).lineLimit(2)
            Spacer()
            if let action = toast.action, let label = toast.actionLabel {
                Button(label) { action() }
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            Button { onDismiss() } label: {
                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Toast Overlay Modifier

struct ToastOverlay: ViewModifier {

    @ObservedObject var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                ForEach(manager.toasts) { toast in
                    ToastRow(toast: toast) {
                        manager.toasts.removeAll { $0.id == toast.id }
                    }
                }
            }
            .padding(.bottom, 88)
            .padding(.horizontal)
            .animation(.spring(duration: 0.3), value: manager.toasts.count)
        }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
