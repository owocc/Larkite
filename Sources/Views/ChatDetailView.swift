import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Color {
    /// Solid elevated background color for the floating input container (Light: #FFFFFF, Dark: #28282B)
    public static let elevatedInputBackground = Color(
        nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .vibrantLight, .vibrantDark])
            if match == .darkAqua || match == .vibrantDark || appearance.name.rawValue.lowercased().contains("dark") {
                // Dark Mode: Elevated Solid Charcoal Grey #28282B
                return NSColor(red: 40.0 / 255.0, green: 40.0 / 255.0, blue: 43.0 / 255.0, alpha: 1.0)
            } else {
                // Light Mode: Elevated Solid Pure White #FFFFFF
                return NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            }
        }
    )
}

@MainActor
public final class ChatDetailViewModel: ObservableObject {
    @Published public var isShowingRightPanel: Bool = false
    @Published public var isHeaderHovered: Bool = false
    @Published public var sidePanelTab: Int = 0 // 0: 属性与成员, 1: 原始 API JSON
    @Published public var copiedField: String? = nil
    @Published public var inputMessageText: String = ""
    @Published public var isEditorExpanded: Bool = false
    @Published public var editorContentHeight: CGFloat = 24
    @Published public var showAttachmentPopover: Bool = false
    @Published public var sendError: String? = nil
    @Published public var memberSearchQuery: String = ""
    public func sendMessage(appState: AppState) async {
        let clean = inputMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        do {
            try await appState.sendTextMessage(clean)
            self.inputMessageText = ""
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                self.isEditorExpanded = false
                self.editorContentHeight = 24
            }
        } catch {
            appState.showNotification(title: "发送消息失败", message: error.localizedDescription, type: .error)
        }
    }
    
    public func pickAndSendImage(appState: AppState) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.png,
            UTType.jpeg,
            UTType.webP,
            UTType.gif,
            UTType.bmp,
            UTType.tiff,
            UTType.heic
        ]
        panel.prompt = "发送图片"
        panel.message = "选择要发送到当前会话的图片"
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url) else { return }
            Task {
                do {
                    try await appState.sendImage(imageData: data, fileName: url.lastPathComponent)
                } catch {
                    appState.showNotification(title: "发送图片失败", message: error.localizedDescription, type: .error)
                }
            }
        }
    }
    
    public func pickAndSendFile(appState: AppState) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "发送文件"
        panel.message = "选择要发送到当前会话的文档或附件 (最大 30MB)"
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url) else { return }
            Task {
                do {
                    try await appState.sendFile(fileData: data, fileName: url.lastPathComponent)
                } catch {
                    appState.showNotification(title: "发送文件失败", message: error.localizedDescription, type: .error)
                }
            }
        }
    }
    
    public func sendClipboard(appState: AppState) {
        Task {
            do {
                let sent = try await appState.sendClipboardImage()
                if !sent {
                    appState.showNotification(title: "剪贴板发送提示", message: "剪贴板中未检测到可发送的图片或文件", type: .warning)
                }
            } catch {
                appState.showNotification(title: "发送剪贴板内容失败", message: error.localizedDescription, type: .error)
            }
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
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = ChatDetailViewModel()
    
    public init(chat: FeishuChatItem?) {
        self.chat = chat
    }
    
    public var body: some View {
        if let chat = chat {
            let currentUser = appState.session?.user
            let title = chat.resolvedDisplayName(
                currentUserName: currentUser?.displayName,
                currentUserId: currentUser?.openId
            )
            let avatarUrl = chat.resolvedAvatarUrl(currentUserId: currentUser?.openId)
            
            HStack(spacing: 0) {
                // Main Chat Column with 100% Full-Height Messages Stream & Floating Liquid Glass Dock
                ZStack(alignment: .bottom) {
                    Color(nsColor: .windowBackgroundColor)
                        .ignoresSafeArea()
                    
                    // 100% Full-Height Scrollable Messages Stream
                    messagesStreamView(chat: chat)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // macOS 26+ Floating Liquid Glass Input Dock or Multi-Select Action Bar
                    if appState.isMultiSelectingMessages {
                        multiSelectBottomBar(chat: chat)
                    } else {
                        messageInputBar
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Collapsible Right-Side Inspector Panel (Apple Messages Seamless Style)
                if viewModel.isShowingRightPanel {
                    rightSideInspectorPanel(chat: chat)
                        .frame(width: 300)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.isShowingRightPanel)
            .toolbar {
                // Center Principal Pill: Avatar + Name + Chevron
                ToolbarItem(placement: .principal) {
                    Button {
                        withAnimation {
                            viewModel.isShowingRightPanel.toggle()
                        }
                        if viewModel.isShowingRightPanel {
                            Task {
                                await appState.loadChatMembers(for: chat, reset: true)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            AvatarView(urlString: avatarUrl, name: title, size: 22)
                            
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("点击打开侧边详细信息与成员面板")
                }
                
                // Trailing Action Buttons: Refresh, Dropdown Actions, Right Inspector Toggle
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task {
                            await appState.loadMessages(for: chat, reset: true)
                            await appState.loadChatMembers(for: chat, reset: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(appState.isLoadingMessages || appState.isLoadingChatMembers ? Color(hex: "3370FF") : .secondary)
                            .rotationEffect(.degrees(appState.isLoadingMessages || appState.isLoadingChatMembers ? 360 : 0))
                            .animation(appState.isLoadingMessages || appState.isLoadingChatMembers ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoadingMessages)
                    }
                    .help("刷新消息与成员")
                    
                    Menu {
                        Button {
                            viewModel.copyToClipboard(text: chat.chatId, field: "header_\(chat.chatId)")
                        } label: {
                            Label("复制 Chat ID", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            withAnimation {
                                viewModel.isShowingRightPanel = true
                                viewModel.sidePanelTab = 0
                            }
                            Task {
                                await appState.loadChatMembers(for: chat, reset: true)
                            }
                        } label: {
                            Label("查看群属性与成员", systemImage: "person.2.fill")
                        }
                        
                        Button {
                            withAnimation {
                                viewModel.isShowingRightPanel = true
                                viewModel.sidePanelTab = 1
                            }
                        } label: {
                            Label("查看 API 原始 JSON 载荷", systemImage: "curlybraces")
                        }
                        
                        Divider()
                        
                        Button {
                            Task {
                                await appState.loadMessages(for: chat, reset: true)
                            }
                        } label: {
                            Label("重新拉取消息", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuIndicator(.hidden)
                    .help("会话更多选项")
                    
                    Button {
                        withAnimation {
                            viewModel.isShowingRightPanel.toggle()
                        }
                        if viewModel.isShowingRightPanel {
                            Task {
                                await appState.loadChatMembers(for: chat, reset: true)
                            }
                        }
                    } label: {
                        Image(systemName: "sidebar.right")
                            .foregroundColor(viewModel.isShowingRightPanel ? configManager.accentColorChoice.color : .secondary)
                    }
                    .help("展开/折叠会话信息面板")
                }
            }
            .sheet(item: $appState.inspectingReadReceiptMessage) { msg in
                MessageReadUsersSheet(message: msg)
            }
            .sheet(item: $appState.inspectingReactionMessage) { msg in
                MessageReactionDetailSheet(message: msg)
            }
        } else {
            emptySelectionView
        }
    }
    // MARK: - Messages Stream View
    
    private func messagesStreamView(chat: FeishuChatItem) -> some View {
        Group {
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
                            // Top Auto-Load Sentinel: Triggers loadMoreMessages on scroll (No Click Needed)
                            if appState.hasMoreMessages {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("正在加载更早历史消息...")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .onAppear {
                                    Task {
                                        await appState.loadMoreMessages()
                                    }
                                }
                            }
                            
                            // High-Performance Equatable Message Cells with 10-min Consecutive Aggregation
                            ForEach(Array(appState.messages.enumerated()), id: \.element.id) { index, msg in
                                let prevMsg: FeishuMessageItem? = index > 0 ? appState.messages[index - 1] : nil
                                let nextMsg: FeishuMessageItem? = index < appState.messages.count - 1 ? appState.messages[index + 1] : nil
                                
                                let isSameSenderAsPrev = prevMsg != nil && prevMsg?.sender?.id == msg.sender?.id
                                let prevTimeMs = prevMsg.flatMap { Double($0.createTime) } ?? 0
                                let currTimeMs = Double(msg.createTime) ?? 0
                                let timeDiffWithPrevMins = prevMsg != nil ? abs(currTimeMs - prevTimeMs) / (1000 * 60) : 999
                                let isPrevConsecutive = isSameSenderAsPrev && timeDiffWithPrevMins < 10
                                
                                let isSameSenderAsNext = nextMsg != nil && nextMsg?.sender?.id == msg.sender?.id
                                let nextTimeMs = nextMsg.flatMap { Double($0.createTime) } ?? 0
                                let timeDiffWithNextMins = nextMsg != nil ? abs(nextTimeMs - currTimeMs) / (1000 * 60) : 999
                                let isNextConsecutive = isSameSenderAsNext && timeDiffWithNextMins < 10
                                
                                let clusterPosition: BubbleClusterPosition = {
                                    if isPrevConsecutive && isNextConsecutive {
                                        return .middle
                                    } else if isPrevConsecutive && !isNextConsecutive {
                                        return .last
                                    } else if !isPrevConsecutive && isNextConsecutive {
                                        return .first
                                    } else {
                                        return .single
                                    }
                                }()
                                
                                let showSenderHeader = !isPrevConsecutive
                                let showTime = !isPrevConsecutive || timeDiffWithPrevMins >= 10
                                
                                HStack(spacing: 4) {
                                    if appState.isMultiSelectingMessages {
                                        Button {
                                            appState.toggleMessageSelectionForShare(msg.messageId)
                                        } label: {
                                            Image(systemName: appState.selectedMessageIdsForShare.contains(msg.messageId) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(appState.selectedMessageIdsForShare.contains(msg.messageId) ? configManager.accentColorChoice.color : .secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 14)
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    }
                                    
                                    MessageBubbleView(
                                        message: msg,
                                        showSenderHeader: showSenderHeader,
                                        showTime: showTime,
                                        position: clusterPosition
                                    )
                                    .equatable()
                                }
                                .id(msg.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if appState.isMultiSelectingMessages {
                                        appState.toggleMessageSelectionForShare(msg.messageId)
                                    }
                                }
                            }
                            
                            // Bottom breathing spacer dynamically adapting to floating dock expansion & reply bar (with 16pt bottom margin)
                            Color.clear
                                .frame(height: viewModel.isEditorExpanded ? 350 : (appState.replyingToMessage != nil ? min(220, max(112, viewModel.editorContentHeight + 88)) : min(180, max(76, viewModel.editorContentHeight + 52))))
                                .id("messages_bottom_anchor")
                        }
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo("messages_bottom_anchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: appState.messages.last?.id) { _ in
                        if !appState.isLoadingMessages {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    proxy.scrollTo("messages_bottom_anchor", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onChange(of: appState.messages.count) { _ in
                        if !appState.isLoadingMessages {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    proxy.scrollTo("messages_bottom_anchor", anchor: .bottom)
                                }
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
            Text("正在获取聊天消息...")
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
            
            Text("无法获取会话消息记录")
                .font(.system(size: 14, weight: .semibold))
            
            Text(error)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
            
            Text("暂无消息记录，发送第一条消息开始会话")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    // MARK: - Multi-Message Selection Action Bar (Snapshot Sharing Easter Egg)
    
    private func multiSelectBottomBar(chat: FeishuChatItem) -> some View {
        HStack(spacing: 12) {
            // Selected count indicator
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(configManager.accentColorChoice.color)
                Text("已选择 \(appState.selectedMessageIdsForShare.count) 条消息")
                    .font(.system(size: 12, weight: .bold))
            }
            
            Spacer()
            
            // Select All / Deselect All Button
            Button {
                if appState.selectedMessageIdsForShare.count == appState.messages.count {
                    appState.deselectAllMessagesForShare()
                } else {
                    appState.selectAllMessagesForShare()
                }
            } label: {
                Text(appState.selectedMessageIdsForShare.count == appState.messages.count ? "取消全选" : "全选")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // Generate Snapshot Button (SF Symbol, No Emoji)
            Button {
                appState.shareSelectedMessages(chat: chat)
            } label: {
                Label("生成长图卡片", systemImage: "photo.stack")
                    .font(.system(size: 11, weight: .semibold))
                    .fixedSize()
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(appState.selectedMessageIdsForShare.isEmpty)
            
            // Cancel / Exit Button
            Button {
                appState.exitMultiSelectMode()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.secondary.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .help("退出多选")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.elevatedInputBackground
                .clipShape(Capsule())
        )
        .overlay(
            Capsule()
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    
    // MARK: - Liquid Glass Floating Input Dock
    // MARK: - Liquid Glass Floating Input Dock (Telegram macOS Style)
    
    private var messageInputBar: some View {
        let dynamicEditorHeight: CGFloat = viewModel.isEditorExpanded ? 280 : min(120, max(34, viewModel.editorContentHeight + 8))
        
        return VStack(spacing: 6) {
            // Floating Reply Bar (Stacked upwards above input dock)
            if let replying = appState.replyingToMessage {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11))
                        .foregroundColor(configManager.accentColorChoice.color)
                    Text("正在回复: \(replying.parsedContent.previewSummary)")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button {
                        appState.replyingToMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Color.elevatedInputBackground
                        .clipShape(Capsule())
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Bottom Dock: Left Attachment + Middle Expanding Editor + Right Send Button
                HStack(alignment: .bottom, spacing: 8) {
                    // Left: Attachment Liquid Glass Button (34x34 Circle, Fixed Bottom, Native Popover)
                    Button {
                        viewModel.showAttachmentPopover.toggle()
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 34, height: 34)
                            .background(
                                Color.elevatedInputBackground
                                    .clipShape(Circle())
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help("添加附件 (图片、视频、文件)")
                    .popover(isPresented: $viewModel.showAttachmentPopover, arrowEdge: .top) {
                        attachmentPopoverView
                    }
                    
                    // Middle: Auto-Expanding Liquid Glass Message Container
                    ZStack(alignment: .trailing) {
                        PasteableMessageField(
                            text: $viewModel.inputMessageText,
                            placeholder: appState.replyingToMessage != nil ? "输入回复内容 (Enter 发送, Shift+Enter 换行)..." : "输入消息 (Enter 发送, Shift+Enter 换行)...",
                            isExpanded: viewModel.isEditorExpanded,
                            contentHeight: $viewModel.editorContentHeight,
                            onCommit: {
                                Task {
                                    await viewModel.sendMessage(appState: appState)
                                }
                            },
                            onPasteImage: { data, fileName in
                                Task {
                                    do {
                                        try await appState.sendImage(imageData: data, fileName: fileName)
                                    } catch {
                                        appState.showNotification(title: "发送图片失败", message: error.localizedDescription, type: .error)
                                    }
                                }
                            },
                            onPasteFile: { data, fileName in
                                Task {
                                    do {
                                        try await appState.sendFile(fileData: data, fileName: fileName)
                                    } catch {
                                        appState.showNotification(title: "发送文件失败", message: error.localizedDescription, type: .error)
                                    }
                                }
                            }
                        )
                        .padding(.leading, 12)
                        .padding(.trailing, 34)
                        .padding(.vertical, 4)
                        .frame(height: dynamicEditorHeight)
                        
                        // Action Buttons inside Editor:
                        if viewModel.editorContentHeight > 40 || viewModel.isEditorExpanded {
                            // Multi-line / Expanded Mode: Expand button at top-right, Emoji button at bottom-right
                            VStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                            viewModel.isEditorExpanded.toggle()
                                        }
                                    } label: {
                                        Image(systemName: viewModel.isEditorExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, height: 28)
                                            .contentShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help(viewModel.isEditorExpanded ? "收起输入框" : "展开大书写空间 (窗口1/2)")
                                    .padding(.top, 4)
                                    .padding(.trailing, 4)
                                }
                                
                                Spacer()
                                
                                HStack {
                                    Spacer()
                                    Button {
                                        NSApp.orderFrontCharacterPalette(nil)
                                    } label: {
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, height: 28)
                                            .contentShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("唤起 macOS 原生表情面板 (Cmd+Ctrl+Space)")
                                    .padding(.bottom, 4)
                                    .padding(.trailing, 4)
                                }
                            }
                            .frame(height: dynamicEditorHeight)
                        } else {
                            // Single-line Mode: Pure 100% Vertical & Horizontal Centering within Capsule Curve
                            Button {
                                NSApp.orderFrontCharacterPalette(nil)
                            } label: {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, height: 28)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("唤起 macOS 原生表情面板 (Cmd+Ctrl+Space)")
                            .padding(.trailing, 4)
                        }
                    }
                    .background(
                        Color.elevatedInputBackground
                            .clipShape(RoundedRectangle(cornerRadius: viewModel.isEditorExpanded ? 18 : 18, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: viewModel.isEditorExpanded ? 18 : 18, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                    // Right: Send Button (34x34 Circle Liquid Glass, Fixed Bottom)
                    LiquidGlassSendButton(
                        isLoading: appState.isSendingMessage,
                        isDisabled: viewModel.inputMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        Task {
                            await viewModel.sendMessage(appState: appState)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.replyingToMessage?.messageId)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: viewModel.isEditorExpanded)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: viewModel.editorContentHeight)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let fileUrl = url, let data = try? Data(contentsOf: fileUrl) else { return }
                let ext = fileUrl.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "webp", "gif", "bmp", "heic", "tiff"].contains(ext) {
                    Task { @MainActor in
                        try? await appState.sendImage(imageData: data, fileName: fileUrl.lastPathComponent)
                    }
                } else {
                    Task { @MainActor in
                        try? await appState.sendFile(fileData: data, fileName: fileUrl.lastPathComponent)
                    }
                }
            }
            return true
        }
    }
    
    // MARK: - Attachment Popover View
    
    private var attachmentPopoverView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                viewModel.showAttachmentPopover = false
                viewModel.pickAndSendImage(appState: appState)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(configManager.accentColorChoice.color)
                    Text("发送图片与视频 (Photo or Video)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            
            Button {
                viewModel.showAttachmentPopover = false
                viewModel.pickAndSendFile(appState: appState)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .foregroundColor(configManager.accentColorChoice.color)
                    Text("发送文档与附件 (File/PDF/ZIP)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button {
                viewModel.showAttachmentPopover = false
                viewModel.sendClipboard(appState: appState)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.secondary)
                    Text("发送剪贴板内容 (Clipboard)")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 230)
    }
    // MARK: - Right-Side Inspector Panel (Apple Messages Style)
    
    private func rightSideInspectorPanel(chat: FeishuChatItem) -> some View {
        let currentUser = appState.session?.user
        let title = chat.resolvedDisplayName(
            currentUserName: currentUser?.displayName,
            currentUserId: currentUser?.openId
        )
        let avatarUrl = chat.resolvedAvatarUrl(currentUserId: currentUser?.openId)
        
        return VStack(spacing: 0) {
            // Top Bar with Close (✕) Button
            HStack {
                Button {
                    withAnimation {
                        viewModel.isShowingRightPanel = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭面板")
                
                Spacer()
                
                // Segment Switcher
                Picker("", selection: $viewModel.sidePanelTab) {
                    Text("属性与成员").tag(0)
                    Text("API JSON").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            
            ScrollView {
                VStack(spacing: 16) {
                    // Large Circular Avatar & Title Profile Header
                    VStack(spacing: 8) {
                        AvatarView(urlString: avatarUrl, name: title, size: 64)
                            .shadow(radius: 6)
                        
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            if chat.isP2P {
                                StatusBadge("私聊", color: Color.teal, icon: "person.fill")
                            } else if chat.isExternal {
                                StatusBadge("外部群", color: Color(hex: "FF9C00"), icon: "globe")
                            } else {
                                StatusBadge("内部群", color: Color(hex: "3370FF"), icon: "lock.shield")
                            }
                            
                            StatusBadge(chat.statusDescription, color: chat.isDissolved ? .red : .green)
                        }
                    }
                    .padding(.top, 12)
                    
                    // Quick Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            viewModel.copyToClipboard(text: chat.chatId, field: "side_chat_\(chat.chatId)")
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: viewModel.copiedField == "side_chat_\(chat.chatId)" ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 14))
                                Text(viewModel.copiedField == "side_chat_\(chat.chatId)" ? "已复制" : "复制 ID")
                                    .font(.system(size: 10))
                            }
                            .frame(width: 68, height: 48)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        
                        if let owner = chat.ownerId, !owner.isEmpty {
                            Button {
                                Task {
                                    await appState.inspectUser(openId: owner, fallbackName: title)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 14))
                                    Text("用户资料")
                                        .font(.system(size: 10))
                                }
                                .frame(width: 68, height: 48)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if viewModel.sidePanelTab == 0 {
                        // Metadata & Members Content
                        sidePanelPropertiesAndMembers(chat: chat)
                    } else {
                        // Raw JSON Content
                        sidePanelRawJson(chat: chat)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }
        }
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow)
                .ignoresSafeArea()
        )
    }
    
    private func sidePanelPropertiesAndMembers(chat: FeishuChatItem) -> some View {
        VStack(spacing: 14) {
            // Attributes Card
            GlassCard(cornerRadius: 10, padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("会话属性")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    propertyRow(label: "Chat ID", value: chat.chatId, canCopy: true)
                    propertyRow(label: "会话模式", value: chat.modeDescription)
                    
                    if let ownerId = chat.ownerId, !ownerId.isEmpty {
                        propertyRow(label: "群主 ID", value: ownerId, canCopy: true)
                    }
                    
                    if let desc = chat.description, !desc.isEmpty, desc != "单聊会话" {
                        propertyRow(label: "群描述", value: desc, canCopy: true)
                    }
                }
            }
            
            // Members Card
            GlassCard(cornerRadius: 10, padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("群成员")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Text("(\(appState.chatMemberTotal > 0 ? "\(appState.chatMemberTotal)" : "\(appState.chatMembers.count)"))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await appState.loadChatMembers(for: chat, reset: true)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Search box in members
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        TextField("搜索成员...", text: $viewModel.memberSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Divider()
                    
                    if appState.isLoadingChatMembers && appState.chatMembers.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView().controlSize(.small)
                            Text("加载成员中...").font(.system(size: 10)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else if filteredMembers.isEmpty {
                        Text(viewModel.memberSearchQuery.isEmpty ? "暂无群成员数据" : "未找到匹配成员")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(filteredMembers) { member in
                                HStack(spacing: 6) {
                                    Button {
                                        Task {
                                            await appState.inspectUser(openId: member.memberId, fallbackName: member.displayName)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            AvatarView(urlString: UserProfileManager.shared.resolveAvatarUrl(for: member.memberId), name: member.displayName, size: 24)
                                            
                                            Text(member.displayName)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            if member.isOwner(ownerId: chat.ownerId) {
                                                StatusBadge("群主", color: Color(hex: "FF9C00"))
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    // Direct chat button
                                    Button {
                                        Task {
                                            UserProfileManager.shared.registerUser(openId: member.memberId, name: member.displayName)
                                            try? await appState.openDirectChatWithUser(idType: "open_id", idValue: member.memberId)
                                        }
                                    } label: {
                                        Image(systemName: "bubble.left.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: "3370FF"))
                                    }
                                    .buttonStyle(.plain)
                                    .help("发起私聊")
                                }
                                .padding(4)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
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
    
    private func sidePanelRawJson(chat: FeishuChatItem) -> some View {
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
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("原始 API JSON")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    viewModel.copyToClipboard(text: jsonString, field: jsonCopyKey)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.copiedField == jsonCopyKey ? "checkmark" : "doc.on.doc")
                        Text(viewModel.copiedField == jsonCopyKey ? "已复制" : "复制 JSON")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "3370FF"))
                }
                .buttonStyle(.plain)
            }
            
            ScrollView([.horizontal, .vertical]) {
                Text(jsonString)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 260)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func propertyRow(label: String, value: String, canCopy: Bool = false) -> some View {
        let propKey = "prop_\(label)_\(value)"
        return HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 10, design: canCopy ? .monospaced : .default))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            if canCopy {
                Button {
                    viewModel.copyToClipboard(text: value, field: propKey)
                } label: {
                    Image(systemName: viewModel.copiedField == propKey ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundColor(viewModel.copiedField == propKey ? .green : .secondary)
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
            Text("选择左侧会话开始聊天")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
