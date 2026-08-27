import SwiftUI

public struct SidebarView: View {
    @ObservedObject var appState: AppState = .shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // User Header Card
            userHeaderCard
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            
            // Navigation List
            VStack(spacing: 4) {
                ForEach(NavigationTab.allCases) { tab in
                    navButton(tab: tab)
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            // Footer Session info & Logout
            footerSection
                .padding(12)
        }
        .frame(minWidth: 200, maxWidth: 240)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }
    
    private var userHeaderCard: some View {
        Button {
            if let user = appState.session?.user {
                Task {
                    await appState.inspectUser(
                        openId: user.openId ?? user.id,
                        fallbackName: user.displayName,
                        fallbackAvatar: user.bestAvatarUrl
                    )
                }
            }
        } label: {
            HStack(spacing: 10) {
                if let user = appState.session?.user {
                    AvatarView(urlString: user.bestAvatarUrl, name: user.displayName, size: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        
                        Text(user.email ?? user.mobile ?? (appState.session?.tokenType.rawValue ?? "已连接"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    AvatarView(urlString: nil, name: "飞书", size: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("飞书账号")
                            .font(.system(size: 13, weight: .semibold))
                        Text("在线")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("点击查看当前登录账号详细资料")
    }
    
    private func navButton(tab: NavigationTab) -> some View {
        let isSelected = appState.selectedTab == tab
        
        return Button {
            appState.selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? Color(hex: "3370FF") : .secondary)
                    .frame(width: 20)
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if tab == .chats && !appState.chats.isEmpty {
                    Text("\(appState.chats.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color(hex: "3370FF").opacity(0.2) : Color.secondary.opacity(0.15))
                        .foregroundColor(isSelected ? Color(hex: "3370FF") : .secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(hex: "3370FF").opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Button(action: {
                    appState.logout()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 11))
                        Text("退出登录")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("API 正常")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
    }
}
