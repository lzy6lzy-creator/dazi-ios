import SwiftUI

// MARK: - Toast Model

struct ToastItem: Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval

    enum ToastType {
        case success
        case error
        case warning
        case info
    }

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(toast.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(bgColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG)
                .stroke(bgColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .padding(.horizontal, 20)
    }

    private var iconName: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.type {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private var bgColor: Color {
        switch toast.type {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Toast Container (overlay on root view)

struct ToastContainerView: View {
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        VStack {
            if let toast = dataStore.currentToast {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        dataStore.dismissToast()
                    }
            }
            Spacer()
        }
        .padding(.top, 8)
        .animation(.spring(duration: 0.35), value: dataStore.currentToast)
    }
}
