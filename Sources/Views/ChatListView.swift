import SwiftUI

@MainActor
public final class ChatListViewModel: ObservableObject {
    @Published public var showAddChatSheet: Bool = false
    @Published public var selectedIdType: String = "chat_id"
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
    @StateObject private var viewModel = ChatListViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header / Search & Filter Section
            headerSection
                .padding(.horizontal, 12)
                .padding(.top, 12)
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
        }
        .frame(minWidth: 290, maxWidth: 360)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .sheet(isPresented: $viewModel.showAddChatSheet) {
            addChatSheet
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Title, Add & Refresh
            HStack {
                Text("消息会话")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                // Add / Open Direct Chat
                Button {
                    viewModel.showAddChatSheet = true
                } label: {
                    Image(systemName: "plus.bubble.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "3370FF"))
                }
                .buttonStyle(.plain)
                .help("按 Chat ID / Open ID 发起或查询私聊")
                
                // Refresh
                Button {
                    Task {
                        await appState.loadChats(reset: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(appState.isLoadingChats ? Color(hex: "3370FF") : .secondary)
                        .rotationEffect(.degrees(appState.isLoadingChats ? 360 : 0))
                        .animation(appState.isLoadingChats ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoadingChats)
                }
                .buttonStyle(.plain)
                .help("刷新会话列表 (Cmd+R)")
            }
            
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
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
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(ChatFilterMode.allCases) { mode in
                        filterPill(mode: mode)
                    }
                }
            }
        }
    }
    
    private func filterPill(mode: ChatFilterMode) -> some View {
        let isSelected = appState.filterMode == mode
        return Button {
            appState.filterMode = mode
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(hex: "3370FF") : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color(hex: "3370FF").opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
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
                        .font(.system(size: 32))
                        .foregroundColor(Color.teal)
                    
                    Text("暂无活跃单聊会话")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("飞书群列表 API 不包含单聊。您可以从下方选择联系人或点击上方「+」直接发起私聊：")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.top, 16)
                
                if !appState.contacts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("企业联系人")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        ForEach(appState.contacts) { contact in
                            Button {
                                appState.openContactChat(contact)
                            } label: {
                                HStack(spacing: 10) {
                                    AvatarView(urlString: contact.bestAvatarUrl, name: contact.displayName, size: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(contact.jobTitle ?? contact.email ?? contact.id)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "bubble.right.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "3370FF"))
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                } else {
                    Button("输入 Chat ID / Open ID 发起单聊") {
                        viewModel.showAddChatSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Spacer()
            }
            .padding(12)
        }
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
            
            Text("支持输入飞书会话 ID (`oc_...`) 或用户 Open ID (`ou_...`)、User ID 快速发起并打开单聊。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
            
            Picker("查询模式", selection: $viewModel.selectedIdType) {
                Text("Chat ID (oc_...)").tag("chat_id")
                Text("User Open ID (ou_...)").tag("open_id")
                Text("User ID").tag("user_id")
                Text("企业邮箱").tag("email")
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(inputFieldLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
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
                    "发起 / 打开",
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
        .frame(width: 440)
    }
    
    private var inputFieldLabel: String {
        switch viewModel.selectedIdType {
        case "chat_id": return "输入会话 Chat ID"
        case "open_id": return "输入用户 Open ID"
        case "user_id": return "输入用户 User ID"
        case "email": return "输入用户企业邮箱"
        default: return "输入标识符"
        }
    }
    
    private var inputFieldPlaceholder: String {
        switch viewModel.selectedIdType {
        case "chat_id": return "oc_xxxxxxxxxxxxxxxxxxxxxxxx"
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
