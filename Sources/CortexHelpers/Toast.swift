import SwiftUI
import CortexUI

/// A transient banner shown at the bottom of the window. Drive it from a single
/// `@StateObject` and attach with `.toasts(center)`:
///
/// ```swift
/// @StateObject private var toasts = ToastCenter()
/// // …
/// .toasts(toasts)
/// toasts.success("Saved")
/// ```
@MainActor
public final class ToastCenter: ObservableObject {
    public enum Kind: Sendable { case success, error, info }

    public struct Toast: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let message: String
        public let kind: Kind
    }

    @Published public var current: Toast?
    private var dismissTask: Task<Void, Never>?

    public init() {}

    /// Shows a toast, auto-dismissing after a short delay (longer for errors).
    public func show(_ message: String, kind: Kind = .info) {
        current = Toast(message: message, kind: kind)
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(kind == .error ? 4 : 2.2))
            if !Task.isCancelled { self?.current = nil }
        }
    }

    public func success(_ m: String) { show(m, kind: .success) }
    public func error(_ m: String) { show(m, kind: .error) }
    public func info(_ m: String) { show(m, kind: .info) }
}

private struct ToastOverlay: ViewModifier {
    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = center.current {
                HStack(spacing: 9) {
                    Image(systemName: icon(toast.kind))
                        .foregroundStyle(color(toast.kind))
                    Text(toast.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(color(toast.kind).opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { center.current = nil }
            }
        }
        .animation(.cortex.bouncy, value: center.current)
    }

    private func icon(_ k: ToastCenter.Kind) -> String {
        switch k {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func color(_ k: ToastCenter.Kind) -> Color {
        switch k {
        case .success: return .green
        case .error: return .red
        case .info: return Brand.accent
        }
    }
}

public extension View {
    /// Attaches the toast overlay backed by `center`.
    func toasts(_ center: ToastCenter) -> some View { modifier(ToastOverlay(center: center)) }
}
