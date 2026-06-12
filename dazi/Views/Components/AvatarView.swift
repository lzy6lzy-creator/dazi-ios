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

// MARK: - Emoji Data

struct EmojiCategory {
    let name: String
    let icon: String
    let emojis: [String]
}

enum EmojiLibrary {
    static let categories: [EmojiCategory] = [
        EmojiCategory(name: "常用", icon: "clock", emojis: [
            "😊", "😎", "🤗", "🥰", "😄", "🤓",
            "😜", "🥳", "😇", "🤩", "😋", "🫡",
            "🙃", "😌", "🤭", "😏", "🫢", "🤔",
        ]),
        EmojiCategory(name: "表情", icon: "face.smiling", emojis: [
            "😀", "😃", "😆", "😁", "😅", "🤣",
            "😂", "🙂", "😉", "😍", "🥲", "😘",
            "😗", "😙", "😚", "😛", "🤑", "🤪",
            "😝", "🤫", "🫠", "😐", "😑", "😶",
            "🫥", "😒", "🙄", "😬", "😮‍💨", "🤥",
            "😔", "😪", "🤤", "😴", "🥱", "😷",
            "🤒", "🤕", "🤢", "🤮", "🥵", "🥶",
            "🥴", "😵", "😵‍💫", "🤯", "🤠", "🥸",
            "😈", "👿", "👹", "👺", "🤡", "💀",
            "☠️", "👻", "👽", "👾", "🤖", "🎃",
        ]),
        EmojiCategory(name: "手势", icon: "hand.raised", emojis: [
            "👋", "🤚", "🖐️", "✋", "🖖", "🫱",
            "🫲", "🫳", "🫴", "👌", "🤌", "🤏",
            "✌️", "🤞", "🫰", "🤟", "🤘", "🤙",
            "👈", "👉", "👆", "🖕", "👇", "☝️",
            "🫵", "👍", "👎", "✊", "👊", "🤛",
            "🤜", "👏", "🙌", "🫶", "👐", "🤲",
            "🤝", "🙏", "✍️", "💪", "🦾", "🦿",
        ]),
        EmojiCategory(name: "动物", icon: "hare", emojis: [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊",
            "🐻", "🐼", "🐻‍❄️", "🐨", "🐯", "🦁",
            "🐮", "🐷", "🐸", "🐵", "🙈", "🙉",
            "🙊", "🐔", "🐧", "🐦", "🦆", "🦅",
            "🦉", "🦇", "🐺", "🐗", "🐴", "🦄",
            "🐝", "🪱", "🐛", "🦋", "🐌", "🐞",
            "🐙", "🦑", "🦀", "🐡", "🐠", "🐟",
            "🐬", "🐳", "🐋", "🦈", "🐊", "🐅",
            "🐆", "🦓", "🦍", "🦧", "🐘", "🦛",
            "🦏", "🐪", "🐫", "🦒", "🦘", "🦬",
        ]),
        EmojiCategory(name: "植物", icon: "leaf", emojis: [
            "🌵", "🎄", "🌲", "🌳", "🌴", "🪵",
            "🌱", "🌿", "☘️", "🍀", "🎍", "🪴",
            "🎋", "🍃", "🍂", "🍁", "🪻", "🌺",
            "🌸", "🌼", "🌻", "🌹", "🌷", "🪷",
            "💐", "🌾", "🫧", "🍄", "🪨", "🌰",
        ]),
        EmojiCategory(name: "食物", icon: "fork.knife", emojis: [
            "🍎", "🍐", "🍊", "🍋", "🍌", "🍉",
            "🍇", "🍓", "🫐", "🍈", "🍒", "🍑",
            "🥭", "🍍", "🥥", "🥝", "🍅", "🥑",
            "🍔", "🍟", "🍕", "🌭", "🥪", "🌮",
            "🌯", "🫔", "🥗", "🍜", "🍝", "🍣",
            "🍱", "🍙", "🍚", "🍛", "🍲", "🫕",
            "🥟", "🧁", "🍰", "🎂", "🍮", "🍩",
            "🍪", "🍫", "🍬", "🍭", "🍡", "🧋",
            "☕", "🍵", "🥤", "🧃", "🍺", "🍷",
        ]),
        EmojiCategory(name: "活动", icon: "sportscourt", emojis: [
            "⚽", "🏀", "🏈", "⚾", "🥎", "🎾",
            "🏐", "🏉", "🥏", "🎱", "🏓", "🏸",
            "🥊", "🥋", "⛳", "⛸️", "🎣", "🤿",
            "🎿", "🛷", "🥌", "🎯", "🪀", "🪁",
            "🎮", "🕹️", "🎲", "🧩", "♟️", "🎰",
            "🎨", "🧵", "🪡", "🧶", "🎭", "🎪",
            "🎤", "🎧", "🎼", "🎹", "🥁", "🪘",
            "🎷", "🎺", "🪗", "🎸", "🎻", "🪕",
        ]),
        EmojiCategory(name: "旅行", icon: "airplane", emojis: [
            "🚗", "🚕", "🚌", "🏎️", "🚓", "🚑",
            "🚒", "🚐", "🛻", "🚚", "🚛", "🚜",
            "🏍️", "🛵", "🚲", "🛴", "🛹", "🛼",
            "🚁", "✈️", "🛩️", "🚀", "🛸", "⛵",
            "🚢", "🗼", "🗽", "⛩️", "🕌", "🛕",
            "🏛️", "⛪", "🕍", "🏰", "🏯", "🎡",
            "🎢", "🎠", "⛲", "⛱️", "🏖️", "🏝️",
            "🏔️", "⛰️", "🌋", "🗻", "🏕️", "🏜️",
        ]),
        EmojiCategory(name: "物品", icon: "desktopcomputer", emojis: [
            "⌚", "📱", "💻", "⌨️", "🖥️", "🖨️",
            "🖱️", "💾", "💿", "📷", "📸", "🎥",
            "📽️", "📺", "📻", "🔮", "🪄", "🎩",
            "📿", "💎", "🔑", "🗝️", "🛡️", "🔧",
            "🧲", "⚗️", "🧪", "🧫", "🧬", "🔬",
            "🔭", "📡", "💡", "🔦", "🏮", "🪔",
            "📖", "📚", "📝", "✏️", "🖊️", "🖋️",
        ]),
        EmojiCategory(name: "符号", icon: "star", emojis: [
            "❤️", "🧡", "💛", "💚", "💙", "💜",
            "🖤", "🤍", "🤎", "💔", "❤️‍🔥", "💖",
            "💗", "💓", "💞", "💕", "💝", "💘",
            "⭐", "🌟", "✨", "💫", "🔥", "💥",
            "⚡", "🌈", "☀️", "🌤️", "⛅", "🌙",
            "🌍", "🌎", "🌏", "🪐", "💧", "🌊",
            "🎵", "🎶", "🔔", "🎀", "🎁", "🏆",
            "🏅", "🥇", "🥈", "🥉", "🎖️", "🏵️",
        ]),
    ]
}

/// 带相机图标的头像选择器，支持从相册上传图片或从全量 emoji 中选择
struct AvatarPickerView: View {
    @Binding var imageData: Data?
    @Binding var emoji: String
    let emojiOptions: [String]
    var size: CGFloat = 88
    var accentColor: Color = AppTheme.primaryColor
    var gridHeight: CGFloat = 180

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedCategoryIndex = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
    private let categories = EmojiLibrary.categories

    var body: some View {
        VStack(spacing: 12) {
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

            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(categories.indices, id: \.self) { index in
                            Button {
                                selectedCategoryIndex = index
                            } label: {
                                Image(systemName: categories[index].icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(selectedCategoryIndex == index ? accentColor : .secondary)
                                    .frame(width: 32, height: 28)
                                    .background(
                                        selectedCategoryIndex == index
                                            ? accentColor.opacity(0.12)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical, 6)

                Divider().padding(.horizontal, 4)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(categories[selectedCategoryIndex].emojis, id: \.self) { emojiOption in
                            Button {
                                emoji = emojiOption
                                imageData = nil
                                selectedPhoto = nil
                            } label: {
                                Text(emojiOption)
                                    .font(.system(size: 26))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        imageData == nil && emoji == emojiOption
                                            ? accentColor.opacity(0.2)
                                            : AppTheme.systemBubbleColor
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
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                }
                .frame(height: gridHeight)
            }
            .padding(.horizontal, 12)
            .background(AppTheme.systemBubbleColor.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
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
