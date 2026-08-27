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
        .sheet(isPresented: $appState.isShowingDebug) {
            debugModalSheet
        }
    }
    private var notLoggedInPlaceholderView: some View {
        VStack(spacing: 16) {
            if let appIcon = NSApp.applicationIconImage ?? NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(configManager.accentColorChoice.color)
            }
            Text("欢迎使用 Larkite")
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
