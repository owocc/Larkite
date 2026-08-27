import SwiftUI

public struct MainView: View {
    @ObservedObject var appState: AppState = .shared
    
    public init() {}
    
    public var body: some View {
        Group {
            if appState.isLoggedIn {
                authenticatedLayout
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 860, minHeight: 580)
    }
    
    private var authenticatedLayout: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView()
            
            Divider()
            
            // Main Content depending on Selected Tab
            switch appState.selectedTab {
            case .chats:
                HStack(spacing: 0) {
                    ChatListView()
                    Divider()
                    ChatDetailView(chat: appState.selectedChat)
                }
            case .settings:
                SettingsView()
            case .debug:
                DebugView()
            }
        }
    }
}
