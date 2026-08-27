import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public final class ChatDetailViewModel: ObservableObject {
    @Published public var isShowingRightPanel: Bool = false
    @Published public var isHeaderHovered: Bool = false
    @Published public var sidePanelTab: Int = 0 // 0: 属性与成员, 1: 原始 API JSON
    @Published public var copiedField: String? = nil
    @Published public var inputMessageText: String = ""
    @Published public var isEditorExpanded: Bool = false
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
                    self.sendError = "发送图片失败: \(error.localizedDescription)"
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
                    self.sendError = "发送文件失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func sendClipboard(appState: AppState) {
        Task {
            do {
                let sent = try await appState.sendClipboardImage()
                if !sent {
                    self.sendError = "剪贴板中未检测到可发送的图片或文件"
                }
            } catch {
                self.sendError = "发送剪贴板内容失败: \(error.localizedDescription)"
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
                    
                    // macOS 26+ Floating Liquid Glass Input Dock
                    messageInputBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Collapsible Right-Side Inspector Panel (Apple Messages Style)
                if viewModel.isShowingRightPanel {
                    Divider()
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
                            
                            // High-Performance Equatable Message Cells (120 FPS Buttery Smooth)
                            ForEach(appState.messages) { msg in
                                MessageBubbleView(message: msg)
                                    .equatable()
                                    .id(msg.id)
                            }
                            
                            // Bottom breathing spacer dynamically adapting to floating dock expansion
                            Color.clear
                                .frame(height: viewModel.isEditorExpanded ? 310 : (viewModel.inputMessageText.count > 40 || viewModel.inputMessageText.contains("\n") ? 120 : 70))
                        }
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        if let lastId = appState.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                    .onChange(of: appState.messages.count) { oldCount, newCount in
                        if newCount > oldCount && !appState.isLoadingMessages {
                            if let lastId = appState.messages.last?.id {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(lastId, anchor: .bottom)
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
    
    // MARK: - Liquid Glass Floating Input Dock
    // MARK: - Liquid Glass Floating Input Dock (Telegram macOS Style)
    
    private var messageInputBar: some View {
        VStack(spacing: 6) {
            // Floating Reply Bar
            if let replying = appState.replyingToMessage {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11))
                        .foregroundColor(configManager.accentColorChoice.color)
                    Text("正在回复: \(replying.parsedContent.previewSummary)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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
                    ZStack {
                        VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                        Color(nsColor: .controlBackgroundColor).opacity(0.75)
                    }
                    .clipShape(Capsule())
                )
                .overlay(
                    Capsule()
                        .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 16)
            }
            
            // Error toast if any
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
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            }
            
            // Telegram macOS Style Floating Input Dock Bar
            GeometryReader { geo in
                let isLongText = viewModel.inputMessageText.count > 40 || viewModel.inputMessageText.contains("\n")
                let windowHalfHeight: CGFloat = max(200, min(400, geo.size.height > 0 ? geo.size.height * 0.5 : 260))
                let dynamicHeight: CGFloat = viewModel.isEditorExpanded ? windowHalfHeight : (isLongText ? 76 : 36)
                
                HStack(alignment: .bottom, spacing: 8) {
                    // Left: Attachment Button 📎 (Liquid Glass Circle Button, matching reference image b3c33f8aba9d8c44.png)
                    Menu {
                        Button {
                            viewModel.pickAndSendImage(appState: appState)
                        } label: {
                            Label("发送图片与视频 (Photo or Video)", systemImage: "photo.on.rectangle.angled")
                        }
                        
                        Button {
                            viewModel.pickAndSendFile(appState: appState)
                        } label: {
                            Label("发送文档与附件 (File)", systemImage: "doc")
                        }
                        
                        Divider()
                        
                        Button {
                            viewModel.sendClipboard(appState: appState)
                        } label: {
                            Label("发送剪贴板内容 (Clipboard)", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(
                                ZStack {
                                    VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                                    Color(nsColor: .controlBackgroundColor).opacity(0.65)
                                }
                                .clipShape(Circle())
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("添加附件 (图片、视频、文件)")
                    
                    // Middle: Auto-Expanding Liquid Glass Message Field
                    ZStack(alignment: .topTrailing) {
                        PasteableMessageField(
                            text: $viewModel.inputMessageText,
                            placeholder: appState.replyingToMessage != nil ? "输入回复内容 (Enter 发送, Shift+Enter 换行)..." : "输入消息 (Enter 发送, Shift+Enter 换行)...",
                            isExpanded: viewModel.isEditorExpanded,
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
                                        viewModel.sendError = "发送图片失败: \(error.localizedDescription)"
                                    }
                                }
                            },
                            onPasteFile: { data, fileName in
                                Task {
                                    do {
                                        try await appState.sendFile(fileData: data, fileName: fileName)
                                    } catch {
                                        viewModel.sendError = "发送文件失败: \(error.localizedDescription)"
                                    }
                                }
                            }
                        )
                        .padding(.leading, 12)
                        .padding(.trailing, 32)
                        .padding(.vertical, 4)
                        .frame(height: dynamicHeight)
                        
                        // Floating Controls inside Input Dock (Expand Top-Right & Emoji Bottom-Right)
                        VStack {
                            // Expand/Collapse Button (Top-Right of input field when text is long or expanded)
                            if isLongText || viewModel.isEditorExpanded {
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
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                    .help(viewModel.isEditorExpanded ? "收起输入框" : "展开大书写空间 (窗口1/2)")
                                }
                            }
                            
                            Spacer()
                            
                            // Native macOS Emoji Palette Invoker Button (Bottom-Right of input field)
                            HStack {
                                Spacer()
                                Button {
                                    NSApp.orderFrontCharacterPalette(nil)
                                } label: {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                                .help("唤起 macOS 原生表情面板 (Cmd+Ctrl+Space)")
                            }
                        }
                        .frame(height: dynamicHeight)
                    }
                    .background(
                        ZStack {
                            VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                            Color(nsColor: .controlBackgroundColor).opacity(0.65)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: viewModel.isEditorExpanded ? 18 : 20, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: viewModel.isEditorExpanded ? 18 : 20, style: .continuous)
                            .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                    
                    // Right: Fixed Send Button 🚀
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
                .padding(.bottom, 12)
            }
            .frame(height: {
                let isLongText = viewModel.inputMessageText.count > 40 || viewModel.inputMessageText.contains("\n")
                if viewModel.isEditorExpanded {
                    return 280
                } else if isLongText {
                    return 88
                } else {
                    return 48
                }
            }())
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: viewModel.isEditorExpanded)
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
            
            Divider()
            
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
