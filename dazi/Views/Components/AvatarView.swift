import SwiftUI
import PhotosUI

/// 可复用的头像视图，优先显示自定义图片，回退到 Emoji
struct AvatarView: View {
    let imageData: Data?
    let emoji: String
    let size: CGFloat
    var backgroundColor: Color = Color.gray.opacity(0.08)

    var body: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(emoji.isEmpty ? "😊" : emoji)
                .font(.system(size: size * 0.55))
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
    }
}

/// 带相机图标的头像选择器，支持从相册上传图片或选择 Emoji
struct AvatarPickerView: View {
    @Binding var imageData: Data?
    @Binding var emoji: String
    let emojiOptions: [String]
    var size: CGFloat = 88
    var accentColor: Color = AppTheme.primaryColor

    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 16) {
            // 头像预览 + 上传按钮（仅相机图标可点击）
            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(
                        imageData: imageData,
                        emoji: emoji,
                        size: size,
                        backgroundColor: accentColor.opacity(0.1)
                    )

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: size * 0.28))
                            .foregroundStyle(accentColor)
                            .background(Circle().fill(.white).frame(width: size * 0.22, height: size * 0.22))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Emoji 选项网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(emojiOptions, id: \.self) { emojiOption in
                    Button {
                        emoji = emojiOption
                        imageData = nil // 选择 Emoji 时清除自定义图片
                        selectedPhoto = nil
                    } label: {
                        Text(emojiOption)
                            .font(.system(size: 26))
                            .frame(width: 44, height: 44)
                            .background(
                                imageData == nil && emoji == emojiOption
                                    ? accentColor.opacity(0.2)
                                    : Color(.systemGray6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
                            .overlay {
                                if imageData == nil && emoji == emojiOption {
                                    RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                                        .stroke(accentColor, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    // 压缩图片到合理大小
                    if let uiImage = UIImage(data: data) {
                        let maxDimension: CGFloat = 400
                        let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height, 1.0)
                        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)

                        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                        uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()

                        await MainActor.run {
                            imageData = resizedImage?.jpegData(compressionQuality: 0.7) ?? data
                        }
                    } else {
                        await MainActor.run {
                            imageData = data
                        }
                    }
                }
            }
        }
    }
}
