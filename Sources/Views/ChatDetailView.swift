import SwiftUI
import AppKit

@MainActor
public final class ChatDetailViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0 // 0: 消息流, 1: 群聊属性与成员, 2: API JSON
    @Published public var copiedField: String? = nil
    @Published public var inputMessageText: String = ""
    @Published public var sendError: String? = nil
    @Published public var memberSearchQuery: String = ""
    
    public init() {}
    
    public func sendMessage(appState: AppState) async {
        let clean = inputMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        sendError = nil
        do {
            try await appState.sendTextMessage(clean)
            self.inputMessageText = ""
        } catch {
            self.sendError = error.localizedDescription
        }
    }
    
    public func copyToClipboard(text: String, field: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        self.copiedField = field
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.copiedField == field {
                self?.copiedField = nil
            }
        }
    }
}

public struct ChatDetailView: View {
    let chat: FeishuChatItem?
    
    @ObservedObject var appState: AppState = .shared
    @StateObject private var viewModel = ChatDetailViewModel()
    
    public init(chat: FeishuChatItem?) {
        self.chat = chat
    }
    
    public var body: some View {
        if let chat = chat {
            VStack(spacing: 0) {
                // Header Bar
                headerBar(chat: chat)
                
                Divider()
                
                // Mode Segment Switcher
                modeSelectorBar
                
                Divider()
                
                // Mode Content
                if viewModel.selectedTab == 0 {
                    messagesStreamView(chat: chat)
                } else if viewModel.selectedTab == 1 {
                    overviewAndMembersTab(chat: chat)
                } else {
                    rawJsonTab(chat: chat)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            emptySelectionView
        }
    }
    
    // MARK: - Header Bar
    
    private func headerBar(chat: FeishuChatItem) -> some View {
        let currentUser = appState.session?.user
        let title = chat.resolvedDisplayName(
            currentUserName: currentUser?.displayName,
            currentUserId: currentUser?.openId
        )
        let avatarUrl = chat.resolvedAvatarUrl(currentUserId: currentUser?.openId)
        
        return HStack(spacing: 14) {
            AvatarView(urlString: avatarUrl, name: title, size: 40)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    if chat.isP2P {
                        StatusBadge("私聊", color: Color.teal, icon: "person.fill")
                    } else if chat.isExternal {
                        StatusBadge("外部群", color: Color(hex: "FF9C00"), icon: "globe")
                    } else {
                        StatusBadge("内部群", color: Color(hex: "3370FF"), icon: "lock.shield")
                    }
                    
                    StatusBadge(chat.statusDescription, color: chat.isDissolved ? .red : .green)
                }
                
                Text(chat.description?.isEmpty == false && chat.description != "单聊会话" && chat.description != currentUser?.displayName ? chat.description! : "ID: \(chat.chatId)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Refresh Messages Button
            Button {
                Task {
                    await appState.loadMessages(for: chat, reset: true)
                    await appState.loadChatMembers(for: chat, reset: true)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(appState.isLoadingMessages || appState.isLoadingChatMembers ? Color(hex: "3370FF") : .secondary)
                    .rotationEffect(.degrees(appState.isLoadingMessages || appState.isLoadingChatMembers ? 360 : 0))
                    .animation(appState.isLoadingMessages || appState.isLoadingChatMembers ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoadingMessages)
            }
            .buttonStyle(.plain)
            .help("刷新消息与成员数据")
            
            // Copy Chat ID
            let copyKey = "header_\(chat.chatId)"
            Button {
                viewModel.copyToClipboard(text: chat.chatId, field: copyKey)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.copiedField == copyKey ? "checkmark" : "doc.on.doc")
                    Text(viewModel.copiedField == copyKey ? "已复制" : "复制 ID")
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
    
    // MARK: - Mode Selector
    
    private var modeSelectorBar: some View {
        HStack(spacing: 8) {
            modeTabButton(
                title: "消息流 (\(appState.messages.count))",
                index: 0,
                icon: "bubble.left.and.bubble.right.fill"
            )
            
            modeTabButton(
                title: "群属性与成员 (\(appState.chatMemberTotal > 0 ? "\(appState.chatMemberTotal)" : "\(appState.chatMembers.count)"))",
                index: 1,
                icon: "person.2.fill"
            )
            
            modeTabButton(
                title: "API JSON 载荷",
                index: 2,
                icon: "curlybraces"
            )
            
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
    
    private func modeTabButton(title: String, index: Int, icon: String) -> some View {
        let isSelected = viewModel.selectedTab == index
        return Button {
            viewModel.selectedTab = index
            if index == 1, let currentChat = chat {
                Task {
                    await appState.loadChatMembers(for: currentChat, reset: true)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? Color(hex: "3370FF") : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(hex: "3370FF").opacity(0.14) : Color(nsColor: .quaternaryLabelColor).opacity(0.12))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Messages Stream View
    
    private func messagesStreamView(chat: FeishuChatItem) -> some View {
        VStack(spacing: 0) {
            if appState.isLoadingMessages && appState.messages.isEmpty {
                loadingMessagesView
            } else if let error = appState.messageError, appState.messages.isEmpty {
                messageErrorView(error: error, chat: chat)
            } else if appState.messages.isEmpty {
                emptyMessagesView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            if appState.hasMoreMessages {
                                Button {
                                    Task {
                                        await appState.loadMoreMessages()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if appState.isLoadingMessages {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                        Text(appState.isLoadingMessages ? "加载中..." : "加载更早的历史消息")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: "3370FF"))
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(Color(hex: "3370FF").opacity(0.08))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                            }
                            
                            ForEach(Array(appState.messages.enumerated()), id: \.element.id) { index, msg in
                                if shouldShowDateHeader(at: index) {
                                    dateHeaderView(title: msg.formattedDateHeader)
                                }
                                
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        if let lastId = appState.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                    .onChange(of: appState.messages.count) { _, _ in
                        if let lastId = appState.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Bottom Interactive Message Input Bar
            messageInputBar
        }
    }
    
    private var messageInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            if let replying = appState.replyingToMessage {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "3370FF"))
                    
                    Text("正在回复: \(replying.parsedContent.previewSummary)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button {
                        appState.replyingToMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(hex: "3370FF").opacity(0.08))
            }
            
            if let error = viewModel.sendError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("发送失败: \(error)")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.08))
            }
            
            HStack(spacing: 10) {
                TextField(
                    appState.replyingToMessage != nil ? "输入回复内容 (Enter 发送)..." : "发送消息 (Enter 发送)...",
                    text: $viewModel.inputMessageText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .onSubmit {
                    Task {
                        await viewModel.sendMessage(appState: appState)
                    }
                }
                
                PrimaryGradientButton(
                    "发送",
                    icon: "paperplane.fill",
                    isLoading: appState.isSendingMessage
                ) {
                    Task {
                        await viewModel.sendMessage(appState: appState)
                    }
                }
                .disabled(viewModel.inputMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isSendingMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    
    private func shouldShowDateHeader(at index: Int) -> Bool {
        if index == 0 { return true }
        let current = appState.messages[index].formattedDateHeader
        let previous = appState.messages[index - 1].formattedDateHeader
        return current != previous
    }
    
    private func dateHeaderView(title: String) -> some View {
        HStack {
            Spacer()
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var loadingMessagesView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("正在获取群聊历史消息...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func messageErrorView(error: String, chat: FeishuChatItem) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("无法获取群消息记录")
                .font(.system(size: 14, weight: .semibold))
            
            Text(error)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("💡 权限检查建议：")
                    .font(.system(size: 11, weight: .semibold))
                Text("1. 应用需开通「获取群聊历史消息」权限 (`im:message` 或 `im:message.history:readonly`)；")
                    .font(.system(size: 11))
                Text("2. 若使用机器人凭据，应用机器人需要已加入该群聊。")
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 24)
            
            Button("重试拉取") {
                Task {
                    await appState.loadMessages(for: chat, reset: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Spacer()
        }
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("该群聊暂无历史消息记录")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Overview and Members Tab
    
    private func overviewAndMembersTab(chat: FeishuChatItem) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Group Metadata Card
                GlassCard(cornerRadius: 14, padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color(hex: "3370FF"))
                            Text("群组详细属性")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Divider()
                        
                        propertyRow(label: "Chat ID", value: chat.chatId, canCopy: true)
                        propertyRow(label: "群名称", value: chat.name ?? "未命名", canCopy: true)
                        propertyRow(label: "群类型", value: chat.isExternal ? "外部群" : "内部群")
                        propertyRow(label: "群状态", value: chat.statusDescription)
                        propertyRow(label: "会话模式", value: chat.modeDescription)
                        
                        if let ownerId = chat.ownerId, !ownerId.isEmpty {
                            propertyRow(
                                label: "群主 ID (\(chat.ownerIdType ?? "user_id"))",
                                value: ownerId,
                                canCopy: true
                            )
                        }
                        
                        if let tenantKey = chat.tenantKey, !tenantKey.isEmpty {
                            propertyRow(label: "Tenant Key", value: tenantKey, canCopy: true)
                        }
                        
                        if let desc = chat.description, !desc.isEmpty {
                            propertyRow(label: "群描述", value: desc, canCopy: true)
                        }
                    }
                }
                
                // Group Members Card
                GlassCard(cornerRadius: 14, padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(Color(hex: "3370FF"))
                            
                            Text("群聊成员")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("(\(appState.chatMemberTotal > 0 ? "\(appState.chatMemberTotal)" : "\(appState.chatMembers.count)") 人)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button {
                                Task {
                                    await appState.loadChatMembers(for: chat, reset: true)
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("刷新成员列表")
                        }
                        
                        // Search inside members
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            TextField("搜索群内成员姓名或 Open ID...", text: $viewModel.memberSearchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                            
                            if !viewModel.memberSearchQuery.isEmpty {
                                Button {
                                    viewModel.memberSearchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Divider()
                        
                        // Members Content
                        if appState.isLoadingChatMembers && appState.chatMembers.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在拉取群成员...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        } else if let error = appState.chatMemberError, appState.chatMembers.isEmpty {
                            VStack(spacing: 6) {
                                Text("未能获取群成员: \(error)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Button("重试") {
                                    Task {
                                        await appState.loadChatMembers(for: chat, reset: true)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else if filteredMembers.isEmpty {
                            Text(viewModel.memberSearchQuery.isEmpty ? "暂无群成员信息" : "未找到匹配成员")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            membersList(chat: chat)
                        }
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            Task {
                await appState.loadChatMembers(for: chat, reset: true)
            }
        }
        .onChange(of: chat.chatId) { _, _ in
            Task {
                await appState.loadChatMembers(for: chat, reset: true)
            }
        }
    }
    
    private var filteredMembers: [FeishuChatMemberItem] {
        let list = appState.chatMembers
        let query = viewModel.memberSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return list
        }
        return list.filter { member in
            member.displayName.lowercased().contains(query) ||
            member.memberId.lowercased().contains(query)
        }
    }
    
    private func membersList(chat: FeishuChatItem) -> some View {
        VStack(spacing: 6) {
            ForEach(filteredMembers) { member in
                HStack(spacing: 10) {
                    AvatarView(
                        urlString: nil,
                        name: member.displayName,
                        size: 32
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(member.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if member.isOwner(ownerId: chat.ownerId) {
                                StatusBadge("群主", color: Color(hex: "FF9C00"), icon: "crown.fill")
                            }
                        }
                        
                        Text(member.memberId)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Copy Member ID uniquely
                    let memberCopyKey = "member_\(member.memberId)"
                    Button {
                        viewModel.copyToClipboard(text: member.memberId, field: memberCopyKey)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: viewModel.copiedField == memberCopyKey ? "checkmark" : "doc.on.doc")
                            Text(viewModel.copiedField == memberCopyKey ? "已复制" : "复制 ID")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.copiedField == memberCopyKey ? .green : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("复制 Member Open ID")
                    
                    // Start Direct Chat Action
                    Button {
                        Task {
                            UserProfileManager.shared.registerUser(openId: member.memberId, name: member.displayName)
                            try? await appState.openDirectChatWithUser(idType: "open_id", idValue: member.memberId)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("私聊")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "3370FF"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "3370FF").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("向该成员发起单聊")
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if appState.hasMoreChatMembers {
                Button {
                    Task {
                        await appState.loadMoreChatMembers()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if appState.isLoadingChatMembers {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(appState.isLoadingChatMembers ? "加载中..." : "加载更多群成员")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "3370FF"))
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Raw JSON Tab
    
    private func rawJsonTab(chat: FeishuChatItem) -> some View {
        let jsonString: String = {
            if let data = try? JSONEncoder().encode(chat),
               let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
            return "{}"
        }()
        
        let jsonCopyKey = "json_\(chat.chatId)"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("群聊 OpenAPI 原始返回载荷")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    viewModel.copyToClipboard(text: jsonString, field: jsonCopyKey)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.copiedField == jsonCopyKey ? "checkmark" : "doc.on.doc")
                        Text(viewModel.copiedField == jsonCopyKey ? "已复制" : "复制 JSON")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(hex: "3370FF"))
            }
            .padding(.horizontal, 20)
            
            ScrollView([.horizontal, .vertical]) {
                Text(jsonString)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func propertyRow(label: String, value: String, canCopy: Bool = false) -> some View {
        let propKey = "prop_\(label)_\(value)"
        return HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, design: canCopy ? .monospaced : .default))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            Spacer()
            
            if canCopy {
                Button {
                    viewModel.copyToClipboard(text: value, field: propKey)
                } label: {
                    Image(systemName: viewModel.copiedField == propKey ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.copiedField == propKey ? .green : .secondary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("复制")
            }
        }
    }
    
    private var emptySelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("选择左侧群聊查看消息记录")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
