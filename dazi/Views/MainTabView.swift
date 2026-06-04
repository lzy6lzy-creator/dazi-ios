import SwiftUI

struct MainTabView: View {
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        @Bindable var store = dataStore

        TabView(selection: $store.selectedTab) {
            Tab("点点", systemImage: store.selectedTab == 0 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right", value: 0) {
                AgentChatView()
            }

            Tab("活动", systemImage: store.selectedTab == 1 ? "calendar.circle.fill" : "calendar", value: 1) {
                EventListView()
            }

            Tab(value: 2) {
                ChatRoomListView()
            } label: {
                Label("聊天", systemImage: store.selectedTab == 2 ? "message.fill" : "message")
            }
            .badge(dataStore.unreadChatCount)

            Tab("我的", systemImage: store.selectedTab == 3 ? "person.fill" : "person", value: 3) {
                ProfileView()
            }
        }
        .tint(AppTheme.primaryColor)
    }
}
