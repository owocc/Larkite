import SwiftUI

public struct MainView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init() {}
    
    public var body: some View {
        Group {
            if appState.isLoggedIn {
                NavigationSplitView {
                    ChatListView()
                        .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 440)
                } detail: {
                    ChatDetailView(chat: appState.selectedChat)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 860, minHeight: 580)
        .sheet(item: $appState.inspectedUser) { user in
            UserProfileSheet(user: user)
        }
        .sheet(isPresented: $appState.isShowingSettings) {
            settingsModalSheet
        }
        .sheet(isPresented: $appState.isShowingDebug) {
            debugModalSheet
        }
    }
    
    private var settingsModalSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("应用设置与权限管理")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("完成") {
                    appState.isShowingSettings = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            SettingsView()
        }
        .frame(width: 620, height: 680)
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
