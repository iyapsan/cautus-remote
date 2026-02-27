import SwiftUI

/// Non-blocking notification toast that appears at the bottom of the window.
///
/// Shows success, error, warning, or info messages with auto-dismiss.
struct ToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void

    @State private var isVisible = false

    private var icon: String {
        switch message.style {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var accentColor: Color {
        switch message.style {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(message.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(message.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .frame(maxWidth: 380)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isVisible = true
            }
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismiss()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.title): \(message.message)")
        .accessibilityAddTraits(.isStaticText)
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - Toast Container Modifier

/// View modifier that shows toast notifications from AppState.
struct ToastContainerModifier: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        @Bindable var appState = appState

        content.overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                ToastView(message: toast) {
                    appState.toastMessage = nil
                }
                .padding(.bottom, 20)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.3), value: appState.toastMessage?.id)
    }
}

extension View {
    /// Attach toast notification support.
    func toastContainer() -> some View {
        modifier(ToastContainerModifier())
    }
}
