import SwiftUI

@MainActor
public final class ChatListViewModel: ObservableObject {
    @Published public var showAddChatSheet: Bool = false
    @Published public var showAccountMenu: Bool = false
    @Published public var selectedIdType: String = "auto"
    @Published public var directIdInput: String = ""
    @Published public var openChatError: String? = nil
    @Published public var isOpeningChat: Bool = false
    
    public init() {}
    
    public func openChat(appState: AppState) async {
        let cleanId = directIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        
        isOpeningChat = true
        openChatError = nil
        
        do {
            try await appState.openDirectChatWithUser(idType: selectedIdType, idValue: cleanId)
            self.showAddChatSheet = false
            self.directIdInput = ""
            self.isOpeningChat = false
        } catch {
            self.openChatError = "获取会话失败: \(error.localizedDescription)"
            self.isOpeningChat = false
        }
    }
}

public struct ChatListView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = ChatListViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header / Traffic light spacing + Search & Filters
            headerSection
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 8)
            
            Divider()
            
            // Content
            if appState.isLoadingChats && appState.chats.isEmpty {
                loadingView
            } else if let error = appState.chatError, appState.chats.isEmpty {
                errorView(error: error)
            } else if appState.filterMode == .p2p && appState.filteredChats.isEmpty {
                p2pEmptyAndContactsView
            } else if appState.filteredChats.isEmpty {
                emptyView
            } else {
                chatListContent
            }
            
            Spacer(minLength: 0)
            
            // Bottom Docked Account & Settings Toolbar
            sidebarBottomSection
        }
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $viewModel.showAddChatSheet) {
            addChatSheet
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Top Row: Title, Add, Refresh, Filter Dropdown Menu (Left of Sidebar Toggle), Sidebar Toggle Button
            HStack(spacing: 6) {
                Text("消息会话")
                    .font(.system(size: 15, weight: .bold))
                
                Spacer()
                
                // Add / Open Direct Chat Button
                Button {
                    viewModel.showAddChatSheet = true
                } label: {
                    Image(systemName: "plus.bubble.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "3370FF"))
                        .padding(5)
                        .background(
                            ZStack {
                                VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                                Color(nsColor: .controlBackgroundColor).opacity(0.45)
                            }
                            .clipShape(Circle())
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1.5)
                }
                .buttonStyle(.plain)
                .help("按 Chat ID / Open ID 发起或查询私聊")
                
                // Refresh Button
                Button {
                    Task {
                        await appState.loadChats(reset: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(appState.isLoadingChats ? Color(hex: "3370FF") : .secondary)
                        .rotationEffect(.degrees(appState.isLoadingChats ? 360 : 0))
                        .animation(appState.isLoadingChats ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoadingChats)
                        .padding(5)
                        .background(
                            ZStack {
                                VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                                Color(nsColor: .controlBackgroundColor).opacity(0.45)
                            }
                            .clipShape(Circle())
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1.5)
                }
                .buttonStyle(.plain)
                .help("刷新会话列表 (Cmd+R)")
                
                // Filter Dropdown Button (macOS 26+ Liquid Glass, positioned strictly to the left of Sidebar Toggle)
                Menu {
                    ForEach(ChatFilterMode.allCases) { mode in
                        Button {
                            appState.filterMode = mode
                        } label: {
                            HStack {
                                Label(mode.menuTitle, systemImage: mode.icon)
                                if appState.filterMode == mode {
                                    Spacer()
                                     Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(appState.filterMode != .all ? Color(hex: "3370FF") : .secondary)
                            .padding(5)
                        
                        if appState.filterMode != .all {
                            Circle()
                                .fill(Color(hex: "3370FF"))
                                .frame(width: 5, height: 5)
                                .offset(x: -1, y: 1)
                        }
                    }
                    .background(
                        ZStack {
                            VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                            Color(nsColor: .controlBackgroundColor).opacity(appState.filterMode != .all ? 0.75 : 0.45)
                        }
                        .clipShape(Circle())
                    )
                    .overlay(
                        Group {
                            if appState.filterMode != .all {
                                Circle()
                                    .strokeBorder(Color(hex: "3370FF").opacity(0.6), lineWidth: 1)
                            } else {
                                Circle()
                                    .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
                            }
                        }
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 1.5)
                }
                .menuStyle(.borderlessButton)
                .help("会话筛选: \(appState.filterMode.menuTitle)")
            }
            
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField("搜索名称或 Chat ID...", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !appState.searchQuery.isEmpty {
                    Button {
                        appState.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Active Filter Chip / Status Indicator if filter is enabled
            if appState.filterMode != .all {
                HStack(spacing: 6) {
                    Image(systemName: appState.filterMode.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "3370FF"))
                    
                    Text("当前筛选: \(appState.filterMode.menuTitle)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "3370FF"))
                    
                    Spacer()
                    
                    Button {
                        appState.filterMode = .all
                    } label: {
                        HStack(spacing: 2) {
                            Text("清除")
                                .font(.system(size: 10))
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("重置为全部会话")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "3370FF").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }
    
    private var chatListContent: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(appState.filteredChats) { chat in
                    ChatRowView(
                        chat: chat,
                        isSelected: appState.selectedChat?.id == chat.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectedChat = chat
                    }
                }
                
                if appState.hasMoreChats {
                    Button {
                        Task {
                            await appState.loadMoreChats()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if appState.isLoadingChats {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appState.isLoadingChats ? "加载中..." : "加载更多会话")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }
    
    private var p2pEmptyAndContactsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 30))
                        .foregroundColor(Color.teal)
                    
                    Text("暂无活跃单聊会话")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("点击下方「深度扫描」核验单聊，或从下方直接选择联系人发起私聊：")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    
                    Button {
                        Task {
                            await appState.deepScanAllChatsAndP2P()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if appState.isScanningP2PChats {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "magnifyingglass.circle.fill")
                            }
                            Text(appState.isScanningP2PChats ? "正在校验 chat_mode..." : "深度扫描全量私聊 (p2p)")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(appState.isScanningP2PChats)
                    .padding(.top, 4)
                }
                .padding(.top, 14)
                
                if !appState.contacts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("企业联系人")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        ForEach(appState.contacts) { contact in
                            Button {
                                appState.openContactChat(contact)
                            } label: {
                                HStack(spacing: 8) {
                                    AvatarView(urlString: contact.bestAvatarUrl, name: contact.displayName, size: 28)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(contact.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(contact.jobTitle ?? contact.email ?? contact.id)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "bubble.right.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "3370FF"))
                                }
                                .padding(6)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer()
            }
            .padding(10)
        }
    }
    
    // MARK: - Sidebar Bottom Docked Toolbar
    
    private var sidebarBottomSection: some View {
        VStack(spacing: 6) {
            Divider()
            
            HStack(spacing: 8) {
                // User Profile Button & Account Switcher
                Button {
                    viewModel.showAccountMenu.toggle()
                } label: {
                    HStack(spacing: 8) {
                        if let user = appState.session?.user {
                            AvatarView(urlString: user.bestAvatarUrl, name: user.displayName, size: 26)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(user.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                Text(user.email ?? (appState.session?.tokenType.rawValue ?? "已连接"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            AvatarView(urlString: nil, name: "飞书", size: 26)
                            Text("飞书账号")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("点击切换账号或管理凭据")
                .popover(isPresented: $viewModel.showAccountMenu, arrowEdge: .top) {
                    accountSwitcherPopover
                }
                
                Spacer()
                
                // Settings Button
                Button {
                    appState.isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("应用设置与权限")
                
                // Debugger Button
                Button {
                    appState.isShowingDebug = true
                } label: {
                    Image(systemName: "curlybraces.square.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("OpenAPI 接口调试台")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
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
                            AvatarView(urlString: acc.avatarUrl, name: acc.displayName, size: 26)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(acc.displayName)
                                    .font(.system(size: 11, weight: isActive ? .bold : .medium))
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
                                    .font(.system(size: 11))
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
                        .padding(5)
                        .background(isActive ? Color(hex: "3370FF").opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(maxHeight: 160)
            
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
        .padding(12)
        .frame(width: 270)
    }
    
    private var addChatSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                    .foregroundColor(Color(hex: "3370FF"))
                Text("发起 / 打开单聊与指定会话")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            
            Text("支持输入任意飞书标识符：会话 ID (`oc_...`)、消息 ID (`om_...`)、用户 Open ID (`ou_...`) 或邮箱，系统会自动识别并定位会话。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
            
            Picker("查询模式", selection: $viewModel.selectedIdType) {
                Text("智能识别").tag("auto")
                Text("Chat ID (oc_)").tag("chat_id")
                Text("Message ID (om_)").tag("message_id")
                Text("Open ID (ou_)").tag("open_id")
                Text("User ID").tag("user_id")
                Text("邮箱").tag("email")
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(inputFieldLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let hint = detectedTypeHint {
                        Text(hint)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "3370FF"))
                    }
                }
                
                TextField(inputFieldPlaceholder, text: $viewModel.directIdInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            
            if let error = viewModel.openChatError {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            HStack {
                Button("取消") {
                    viewModel.showAddChatSheet = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                PrimaryGradientButton(
                    "定位 / 打开会话",
                    icon: "arrow.right",
                    isLoading: viewModel.isOpeningChat
                ) {
                    Task {
                        await viewModel.openChat(appState: appState)
                    }
                }
                .disabled(viewModel.directIdInput.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
    
    private var detectedTypeHint: String? {
        let trimmed = viewModel.directIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("om_") {
            return "✓ 识别为 Message ID"
        } else if trimmed.hasPrefix("oc_") {
            return "✓ 识别为 Chat ID"
        } else if trimmed.hasPrefix("ou_") {
            return "✓ 识别为 User Open ID"
        } else if trimmed.hasPrefix("on_") {
            return "✓ 识别为 Union ID"
        } else if trimmed.contains("@") {
            return "✓ 识别为 企业邮箱"
        }
        return nil
    }
    
    private var inputFieldLabel: String {
        switch viewModel.selectedIdType {
        case "auto": return "输入任意 ID (oc_... / om_... / ou_... / 邮箱)"
        case "chat_id": return "输入会话 Chat ID (oc_...)"
        case "message_id": return "输入消息 Message ID (om_...)"
        case "open_id": return "输入用户 Open ID (ou_...)"
        case "user_id": return "输入用户 User ID"
        case "email": return "输入用户企业邮箱"
        default: return "输入标识符"
        }
    }
    
    private var inputFieldPlaceholder: String {
        switch viewModel.selectedIdType {
        case "auto": return "粘贴 oc_... 或 om_... 或 ou_..."
        case "chat_id": return "oc_xxxxxxxxxxxxxxxxxxxxxxxx"
        case "message_id": return "om_xxxxxxxxxxxxxxxxxxxxxxxx"
        case "open_id": return "ou_xxxxxxxxxxxxxxxxxxxxxxxx"
        case "user_id": return "xxxxxxxx"
        case "email": return "user@company.com"
        default: return ""
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("正在拉取会话列表...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text("拉取会话失败")
                .font(.system(size: 13, weight: .semibold))
            
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            Button("重试") {
                Task {
                    await appState.loadChats(reset: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text(appState.searchQuery.isEmpty ? "暂无会话" : "未找到匹配会话")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            if !appState.searchQuery.isEmpty {
                Button("清除搜索") {
                    appState.searchQuery = ""
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }
            
            Spacer()
        }
    }
}
