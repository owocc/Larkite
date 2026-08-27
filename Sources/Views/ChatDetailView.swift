import SwiftUI
import AppKit

@MainActor
public final class ChatDetailViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0 // 0: 消息流, 1: 群聊属性, 2: API JSON
    @Published public var copiedField: String? = nil
    
    public init() {}
    
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
                    overviewTab(chat: chat)
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
        HStack(spacing: 14) {
            AvatarView(urlString: chat.avatar, name: chat.displayName, size: 40)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(chat.displayName)
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
                
                Text(chat.description?.isEmpty == false ? chat.description! : "ID: \(chat.chatId)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Refresh Messages Button
            Button {
                Task {
                    await appState.loadMessages(for: chat, reset: true)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(appState.isLoadingMessages ? Color(hex: "3370FF") : .secondary)
                    .rotationEffect(.degrees(appState.isLoadingMessages ? 360 : 0))
                    .animation(appState.isLoadingMessages ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoadingMessages)
            }
            .buttonStyle(.plain)
            .help("刷新当前群消息")
            
            // Copy Chat ID
            Button {
                viewModel.copyToClipboard(text: chat.chatId, field: "Chat ID")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.copiedField == "Chat ID" ? "checkmark" : "doc.on.doc")
                    Text(viewModel.copiedField == "Chat ID" ? "已复制" : "复制 ID")
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
        HStack {
            Picker("", selection: $viewModel.selectedTab) {
                Text("消息流 (\(appState.messages.count))").tag(0)
                Text("群组属性").tag(1)
                Text("API JSON 载荷").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
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
                            // Load Earlier Messages Button
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
                            
                            // Message Items with Date Dividers
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
    
    // MARK: - Overview Tab
    
    private func overviewTab(chat: FeishuChatItem) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard(cornerRadius: 14, padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("群组元数据")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
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
            }
            .padding(20)
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
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("群聊 OpenAPI 原始返回载荷")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    viewModel.copyToClipboard(text: jsonString, field: "JSON")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.copiedField == "JSON" ? "checkmark" : "doc.on.doc")
                        Text(viewModel.copiedField == "JSON" ? "已复制" : "复制 JSON")
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
        HStack(alignment: .top) {
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
                    viewModel.copyToClipboard(text: value, field: label)
                } label: {
                    Image(systemName: viewModel.copiedField == label ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.copiedField == label ? .green : .secondary)
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
