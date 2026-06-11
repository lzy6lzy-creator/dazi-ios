import SwiftUI

struct MainTabView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var isKeyboardVisible = false

    var body: some View {
        @Bindable var store = dataStore

        ZStack(alignment: .bottom) {
            Group {
                switch store.selectedTab {
                case 0: AgentChatView()
                case 1: EventListView()
                case 2: ChatRoomListView()
                default: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isKeyboardVisible {
                CoinTabBar(selection: $store.selectedTab, unreadCount: dataStore.unreadChatCount)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.backgroundColor.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: isKeyboardVisible)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
}
