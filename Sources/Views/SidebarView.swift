import SwiftUI

@MainActor
public final class SidebarViewModel: ObservableObject {
    @Published public var showAccountMenu: Bool = false
    public init() {}
}

public struct SidebarView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = SidebarViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // User Header Card with Account Switcher Popover
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
            
            // Footer Session info & Account Actions
            footerSection
                .padding(12)
        }
        .frame(minWidth: 210, maxWidth: 250)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }
    
    private var userHeaderCard: some View {
        Button {
            viewModel.showAccountMenu.toggle()
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
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("点击切换账号或查看资料")
        .popover(isPresented: $viewModel.showAccountMenu, arrowEdge: .trailing) {
            accountSwitcherPopover
        }
    }
    
    private var accountSwitcherPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("飞书账号管理")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(configManager.accounts.count) 个已保存")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Accounts List
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(configManager.accounts) { acc in
                        let isActive = acc.id == configManager.activeAccountId
                        HStack(spacing: 8) {
                            AvatarView(urlString: acc.avatarUrl, name: acc.displayName, size: 28)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(acc.displayName)
                                    .font(.system(size: 12, weight: isActive ? .bold : .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(acc.email ?? acc.id)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            } else {
                                Button {
                                    appState.switchAccount(to: acc.id)
                                    viewModel.showAccountMenu = false
                                } label: {
                                    Text("切换")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: "3370FF"))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: "3370FF").opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    appState.removeAccount(id: acc.id)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("移除该账号")
                            }
                        }
                        .padding(6)
                        .background(isActive ? Color(hex: "3370FF").opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(maxHeight: 180)
            
            Divider()
            
            // Actions
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    viewModel.showAccountMenu = false
                    appState.startAddingNewAccount()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "3370FF"))
                        Text("添加新的飞书账号...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "3370FF"))
                    }
                }
                .buttonStyle(.plain)
                
                if let user = appState.session?.user {
                    Button {
                        viewModel.showAccountMenu = false
                        Task {
                            await appState.inspectUser(
                                openId: user.openId ?? user.id,
                                fallbackName: user.displayName,
                                fallbackAvatar: user.bestAvatarUrl
                            )
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.text.rectangle")
                                .foregroundColor(.secondary)
                            Text("查看个人详细资料卡")
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Button(role: .destructive) {
                    viewModel.showAccountMenu = false
                    appState.logoutCurrentAccount()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("退出当前账号")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 280)
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
                    appState.logoutCurrentAccount()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 11))
                        Text("退出账号")
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
