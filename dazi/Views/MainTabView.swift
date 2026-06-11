import SwiftUI

struct MainTabView: View {
    @Environment(DataStore.self) private var dataStore

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
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 72)
            }

            CoinTabBar(selection: $store.selectedTab, unreadCount: dataStore.unreadChatCount)
                .padding(.bottom, 4)
        }
        .background(AppTheme.backgroundColor.ignoresSafeArea())
    }
}
