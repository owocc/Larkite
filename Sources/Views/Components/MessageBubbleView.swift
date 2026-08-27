import SwiftUI
import AppKit

extension Color {
    /// Native Apple Messages Incoming Bubble Color (Light: #E9E9EB, Dark: #26252A)
    public static let appleMessagesIncomingBubble = Color(
        nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .vibrantLight, .vibrantDark])
            if match == .darkAqua || match == .vibrantDark || appearance.name.rawValue.lowercased().contains("dark") {
                // Dark Mode: Apple Messages Charcoal Grey #26252A
                return NSColor(red: 38.0 / 255.0, green: 37.0 / 255.0, blue: 42.0 / 255.0, alpha: 1.0)
            } else {
                // Light Mode: Apple Messages Light Grey #E9E9EB
                return NSColor(red: 233.0 / 255.0, green: 233.0 / 255.0, blue: 235.0 / 255.0, alpha: 1.0)
            }
        }
    )
}

@MainActor
public final class MessageBubbleViewModel: ObservableObject {
    @Published public var isHovered: Bool = false
    @Published public var showEmojiPicker: Bool = false
    @Published public var copiedToast: Bool = false
    @Published public var actionMessage: String? = nil
    
    public init() {}
    
    public func copyText(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        withAnimation {
            copiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation {
                self?.copiedToast = false
            }
        }
    }
}

public struct MessageBubbleView: View {
    let message: FeishuMessageItem
    let isCurrentUser: Bool
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = MessageBubbleViewModel()
    
    public init(message: FeishuMessageItem, isCurrentUser: Bool = false) {
        self.message = message
        self.isCurrentUser = isCurrentUser
    }
    
    private var isSelfMessage: Bool {
        if isCurrentUser { return true }
        guard let sender = message.sender else { return false }
        if let current = appState.session?.user {
            return sender.id == current.openId || sender.id == current.userId
        }
        return false
    }
    
    public var body: some View {
        let content = message.parsedContent
        
        if case .system(let text) = content {
            systemMessageView(text: text)
        } else if case .recalled = content {
            recalledMessageView
        } else if isSelfMessage {
            myMessageRow(content: content)
        } else {
            otherMessageRow(content: content)
        }
    }
    
    // MARK: - My Messages (Right Aligned, Accent Colored)
    
    private func myMessageRow(content: ParsedMessageContent) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 48)
            
            VStack(alignment: .trailing, spacing: 4) {
                // Time & Status Header
                HStack(spacing: 6) {
                    if let status = viewModel.actionMessage {
                        Text(status)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(configManager.accentColorChoice.color)
                            .transition(.opacity)
                    }
                    
                    Text(message.formattedTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(height: 14)
                
                // Bubble Content with Right-Click Context Menu
                bubbleContent(content: content, isSelf: true)
                    .contextMenu {
                        messageContextMenu(content: content, isSelf: true)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .frame(minHeight: 36, alignment: .trailing)
    }
    
    // MARK: - Other's Messages (Left Aligned, Apple Messages Grey)
    
    private func otherMessageRow(content: ParsedMessageContent) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Sender Avatar
            Button {
                if let senderId = message.sender?.id {
                    Task {
                        await appState.inspectUser(
                            openId: senderId,
                            fallbackName: senderDisplayName,
                            fallbackAvatar: senderAvatarUrl
                        )
                    }
                }
            } label: {
                AvatarView(
                    urlString: senderAvatarUrl,
                    name: senderDisplayName,
                    size: 32
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("查看「\(senderDisplayName)」详细资料")
            
            VStack(alignment: .leading, spacing: 4) {
                // Sender Name, Bot Badge, Time
                HStack(spacing: 6) {
                    Text(senderDisplayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if message.sender?.isAppOrBot ?? false {
                        StatusBadge("Bot", color: Color(hex: "7838FF"))
                    }
                    
                    Text(message.formattedTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let status = viewModel.actionMessage {
                        Text("• \(status)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "3370FF"))
                            .transition(.opacity)
                    }
                }
                .frame(height: 14)
                
                // Bubble Content with Right-Click Context Menu
                bubbleContent(content: content, isSelf: false)
                    .contextMenu {
                        messageContextMenu(content: content, isSelf: false)
                    }
            }
            
            Spacer(minLength: 48)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .frame(minHeight: 36, alignment: .leading)
    }
    
    // MARK: - Native Right-Click Context Menu for Reactions & Actions
    
    @ViewBuilder
    private func messageContextMenu(content: ParsedMessageContent, isSelf: Bool) -> some View {
        Section("回应表情") {
            Button("👍 点赞") {
                sendReaction("THUMBSUP", name: "👍 点赞")
            }
            Button("❤️ 爱心") {
                sendReaction("HEART", name: "❤️ 爱心")
            }
            Button("👏 鼓掌") {
                sendReaction("APPLAUD", name: "👏 鼓掌")
            }
            Button("😄 开心") {
                sendReaction("JOY", name: "😄 开心")
            }
            Button("🎉 庆祝") {
                sendReaction("PARTY", name: "🎉 庆祝")
            }
            Button("🔥 火力") {
                sendReaction("FIRE", name: "🔥 火力")
            }
        }
        
        Divider()
        
        Button {
            appState.replyingToMessage = message
        } label: {
            Label("回复此消息", systemImage: "arrowshape.turn.up.left")
        }
        
        if case .text(let text) = content {
            Button {
                viewModel.copyText(text: text)
            } label: {
                Label("复制文本内容", systemImage: "doc.on.doc")
            }
        }
        
        Button {
            viewModel.copyText(text: message.messageId)
        } label: {
            Label("复制 Message ID", systemImage: "number")
        }
        
        if isSelf {
            Divider()
            Button(role: .destructive) {
                Task {
                    do {
                        try await appState.recallMessageItem(message)
                        withAnimation { viewModel.actionMessage = "已撤回" }
                    } catch {
                        withAnimation { viewModel.actionMessage = "撤回失败: \(error.localizedDescription)" }
                    }
                }
            } label: {
                Label("撤回消息", systemImage: "trash")
            }
        }
        
        if let senderId = message.sender?.id {
            Divider()
            Button {
                Task {
                    await appState.inspectUser(
                        openId: senderId,
                        fallbackName: senderDisplayName,
                        fallbackAvatar: senderAvatarUrl
                    )
                }
            } label: {
                Label("查看发送者资料", systemImage: "person.crop.circle")
            }
        }
    }
    
    private func sendReaction(_ type: String, name: String) {
        Task {
            do {
                try await appState.addReaction(to: message, emojiType: type)
                withAnimation { viewModel.actionMessage = "已回应 \(name)" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { viewModel.actionMessage = nil }
                }
            } catch {
                withAnimation { viewModel.actionMessage = "回应失败: \(error.localizedDescription)" }
            }
        }
    }
    
    @ViewBuilder
    private func bubbleContent(content: ParsedMessageContent, isSelf: Bool) -> some View {
        switch content {
        case .text(let text):
            Text(text)
                .font(.system(size: 13.5))
                .foregroundColor(isSelf ? .white : .primary)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelf ? configManager.accentColorChoice.color : Color.appleMessagesIncomingBubble)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelf ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.8)
                )
        case .image(let imageKey):
            // Apple Messages style: Frameless edge-to-edge image attachment
            MessageImageView(messageId: message.messageId, imageKey: imageKey)
                .contextMenu {
                    Button("复制 Message ID") {
                        viewModel.copyText(text: message.messageId)
                    }
                    Button("回复此图片") {
                        appState.replyingToMessage = message
                    }
                }
            
        case .file(let fileKey, let fileName, let fileSize):
            MessageFileView(
                messageId: message.messageId,
                fileKey: fileKey,
                fileName: fileName,
                fileSize: fileSize
            )
            .contextMenu {
                Button("复制 Message ID") {
                    viewModel.copyText(text: message.messageId)
                }
                Button("回复此文件") {
                    appState.replyingToMessage = message
                }
            }
            
        case .audio(_, let durationMs):
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(isSelf ? .white : Color(hex: "3370FF"))
                Text("语音消息")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelf ? .white : .primary)
                if let ms = durationMs {
                    Text("\(ms / 1000)s")
                        .font(.system(size: 11))
                        .foregroundColor(isSelf ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelf ? configManager.accentColorChoice.color : Color.appleMessagesIncomingBubble)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelf ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.8)
            )
            
        case .media(let fileKey, let imageKey, let fileName, let durationSec):
            MessageMediaView(
                messageId: message.messageId,
                fileKey: fileKey,
                imageKey: imageKey,
                fileName: fileName,
                durationSec: durationSec
            )
            
        case .post(let title, let segments):
            VStack(alignment: .leading, spacing: 6) {
                if let title = title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelf ? .white : .primary)
                }
                
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    renderPostSegment(segment, isSelf: isSelf)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelf ? configManager.accentColorChoice.color : Color.appleMessagesIncomingBubble)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelf ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.8)
            )
            
        case .card(let rawJson):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("飞书消息卡片 (Interactive Card)")
                        .font(.system(size: 12, weight: .semibold))
                }
                
                Text(rawJson)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(4)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appleMessagesIncomingBubble)
            )
            
        case .shareChat(let chatId):
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Color(hex: "3370FF"))
                Text("分享群聊 (Chat ID: \(chatId.prefix(12))...)")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appleMessagesIncomingBubble)
            )
            
        case .rawText(let raw):
            Text(raw)
                .font(.system(size: 12))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appleMessagesIncomingBubble)
                )
                
        default:
            Text("不支持的消息类型: \(message.msgType)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(8)
                .background(Color.appleMessagesIncomingBubble)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    @ViewBuilder
    private func renderPostSegment(_ segment: PostSegment, isSelf: Bool) -> some View {
        switch segment {
        case .text(let text):
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(isSelf ? .white : .primary)
                .textSelection(.enabled)
        case .link(let text, let url):
            if let linkUrl = URL(string: url) {
                Link(text, destination: linkUrl)
                    .font(.system(size: 13))
                    .foregroundColor(isSelf ? .white.opacity(0.9) : Color(hex: "3370FF"))
                    .underline()
            } else {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(isSelf ? .white.opacity(0.9) : Color(hex: "3370FF"))
            }
        case .mention(let name):
            Text("@\(name)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelf ? .white : Color(hex: "3370FF"))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(isSelf ? Color.white.opacity(0.25) : Color(hex: "3370FF").opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        case .image(let imageKey):
            MessageImageView(messageId: message.messageId, imageKey: imageKey)
        case .lineBreak:
            Divider().opacity(0)
        }
    }
    
    private func systemMessageView(text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var recalledMessageView: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10))
                Text("此消息已被撤回")
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var senderDisplayName: String {
        if let mentions = message.mentions, let first = mentions.first, let name = first.name, !name.isEmpty {
            return name
        }
        if let sender = message.sender {
            if sender.isAppOrBot {
                return "机器人应用"
            }
            let currentUserId = appState.session?.user?.openId
            return UserProfileManager.shared.resolveDisplayName(for: sender.id, currentUserId: currentUserId)
        }
        return "飞书成员"
    }
    
    private var senderAvatarUrl: String? {
        if let sender = message.sender {
            if let current = appState.session?.user, (sender.id == current.openId || sender.id == current.userId) {
                return current.bestAvatarUrl
            }
            return UserProfileManager.shared.resolveAvatarUrl(for: sender.id)
        }
        return nil
    }
}
