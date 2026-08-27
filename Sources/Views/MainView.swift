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
                notLoggedInPlaceholderView
            }
        }
        .frame(minWidth: 860, minHeight: 580)
        .onAppear {
            if !appState.isLoggedIn {
                AccountWindowManager.shared.showLoginWindow()
            }
        }
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
    private var notLoggedInPlaceholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "3370FF"))
            
            Text("欢迎使用 Lark Native")
                .font(.system(size: 18, weight: .bold))
            
            Text("请在独立登录窗口中登录或选择企业账号，开始消息与会话管理")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Button {
                AccountWindowManager.shared.showLoginWindow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                    Text("打开账号与登录窗口")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
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
