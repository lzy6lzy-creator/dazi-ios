import SwiftUI

struct ProfileAvatarButton: View {
    let user: User
    let currentUserId: String
    var size: CGFloat = 44
    var backgroundColor: Color = AppTheme.primaryColor.opacity(0.08)
    var strokeColor: Color?
    var strokeLineWidth: CGFloat = 0

    @State private var showProfile = false

    private var canOpenProfile: Bool {
        user.id != currentUserId && !user.isAgent
    }

    var body: some View {
        Group {
            if canOpenProfile {
                Button {
                    showProfile = true
                } label: {
                    avatar
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看\(user.name)主页")
            } else {
                avatar
            }
        }
        .sheet(isPresented: $showProfile) {
            PartnerProfileView(partner: user)
        }
    }

    private var avatar: some View {
        AvatarView(
            imageData: user.avatarImageData,
            emoji: user.avatarEmoji,
            size: size,
            backgroundColor: backgroundColor
        )
        .overlay {
            if let strokeColor, strokeLineWidth > 0 {
                Circle().stroke(strokeColor, lineWidth: strokeLineWidth)
            }
        }
    }
}
