import SwiftUI
import AppKit

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
                
                // Bubble Content
                bubbleContent(content: content, isSelf: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(minHeight: 40, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(viewModel.isHovered ? Color(nsColor: .quaternaryLabelColor).opacity(0.12) : Color.clear)
        )
        .overlay(alignment: .topTrailing) {
            hoverQuickActions
                .padding(.trailing, 16)
                .padding(.top, 2)
                .opacity(viewModel.isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.12), value: viewModel.isHovered)
        }
        .onHover { hovering in
            viewModel.isHovered = hovering
        }
    }
    
    // MARK: - Other's Messages (Left Aligned, Frosted Background)
    
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
                
                // Bubble Content
                bubbleContent(content: content, isSelf: false)
            }
            
            Spacer(minLength: 48)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(minHeight: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(viewModel.isHovered ? Color(nsColor: .quaternaryLabelColor).opacity(0.12) : Color.clear)
        )
        .overlay(alignment: .topTrailing) {
            hoverQuickActions
                .padding(.trailing, 16)
                .padding(.top, 2)
                .opacity(viewModel.isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.12), value: viewModel.isHovered)
        }
        .onHover { hovering in
            viewModel.isHovered = hovering
        }
    }
    
    // MARK: - Floating Quick Actions Menu
    
    private var hoverQuickActions: some View {
        HStack(spacing: 4) {
            // Copy Message ID
            Button {
                viewModel.copyText(text: message.messageId)
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: viewModel.copiedToast ? "checkmark" : "doc.on.doc")
                    Text(viewModel.copiedToast ? "已复制 ID" : "复制 ID")
                }
                .font(.system(size: 9))
                .foregroundColor(viewModel.copiedToast ? .green : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .help("复制 Message ID")
            
            // Reply action
            Button {
                appState.replyingToMessage = message
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                    Text("回复")
                }
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "3370FF"))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .help("回复此消息")
            
            // Reaction action (👍)
            Button {
                Task {
                    do {
                        try await appState.addReaction(to: message, emojiType: "THUMBSUP")
                        withAnimation { viewModel.actionMessage = "已点赞 👍" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { viewModel.actionMessage = nil }
                        }
                    } catch {
                        withAnimation { viewModel.actionMessage = "表情回复: \(error.localizedDescription)" }
                    }
                }
            } label: {
                Text("👍")
                    .font(.system(size: 10))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .help("快捷点赞")
            
            // Recall action
            Button {
                Task {
                    do {
                        try await appState.recallMessageItem(message)
                        withAnimation { viewModel.actionMessage = "已撤回" }
                    } catch {
                        withAnimation { viewModel.actionMessage = "撤回失败: \(error.localizedDescription)" }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "trash")
                    Text("撤回")
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .help("撤回此消息 (需权限)")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.8)
        )
    }
    
    // MARK: - Bubble Content Dispatcher
    
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
                        .fill(isSelf ? configManager.accentColorChoice.color : Color(nsColor: .controlBackgroundColor).opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelf ? Color.white.opacity(0.12) : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
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
                    .fill(isSelf ? configManager.accentColorChoice.color : Color(nsColor: .controlBackgroundColor).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelf ? Color.white.opacity(0.15) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
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
                    .fill(isSelf ? configManager.accentColorChoice.color : Color(nsColor: .controlBackgroundColor).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelf ? Color.white.opacity(0.15) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
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
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
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
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
            
        case .rawText(let raw):
            Text(raw)
                .font(.system(size: 12))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
                
        default:
            Text("不支持的消息类型: \(message.msgType)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
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
