import SwiftUI

public struct MainView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            ChatListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 440)
        } detail: {
            ChatDetailView(chat: appState.selectedChat)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 580)
        .onChange(of: appState.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                AccountWindowManager.shared.closeWindow()
                MainWindowManager.shared.showMainWindow()
            } else {
                MainWindowManager.shared.hideMainWindow()
                AccountWindowManager.shared.showLoginWindow()
            }
        }
        .sheet(item: $appState.inspectedUser) { user in
            UserProfileSheet(user: user)
        }
        .sheet(isPresented: $appState.isShowingDebug) {
            debugModalSheet
        }
    }
    
    private var debugModalSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("OpenAPI 接口调试台")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("完成") {
                    appState.isShowingDebug = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            DebugView()
        }
        .frame(width: 720, height: 620)
    }
}
