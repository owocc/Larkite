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
    @StateObject private var viewModel = MessageBubbleViewModel()
    
    public init(message: FeishuMessageItem, isCurrentUser: Bool = false) {
        self.message = message
        self.isCurrentUser = isCurrentUser
    }
    
    public var body: some View {
        let content = message.parsedContent
        
        if case .system(let text) = content {
            systemMessageView(text: text)
        } else if case .recalled = content {
            recalledMessageView
        } else {
            standardMessageRow(content: content)
        }
    }
    
    private func standardMessageRow(content: ParsedMessageContent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Sender Avatar (Click to inspect profile)
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
                    size: 34
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("点击查看「\(senderDisplayName)」详细资料")
            
            VStack(alignment: .leading, spacing: 4) {
                // Header (Sender Name, Bot Badge, Time, ID Copy)
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
                    
                    if viewModel.isHovered {
                        hoverQuickActions
                    }
                }
                
                // Content Bubble
                bubbleContent(content: content)
                
                // Action status if any
                if let status = viewModel.actionMessage {
                    Text(status)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "3370FF"))
                }
            }
            
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(viewModel.isHovered ? Color(nsColor: .quaternaryLabelColor).opacity(0.15) : Color.clear)
        .onHover { hovering in
            viewModel.isHovered = hovering
        }
    }
    
    private var hoverQuickActions: some View {
        HStack(spacing: 6) {
            // Copy ID
            Button {
                viewModel.copyText(text: message.messageId)
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: viewModel.copiedToast ? "checkmark" : "doc.on.doc")
                    Text(viewModel.copiedToast ? "已复制 ID" : "复制 ID")
                }
                .font(.system(size: 9))
                .foregroundColor(viewModel.copiedToast ? .green : .secondary)
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
            }
            .buttonStyle(.plain)
            .help("回复此消息")
            
            // Reaction action (👍)
            Button {
                Task {
                    do {
                        try await appState.addReaction(to: message, emojiType: "THUMBSUP")
                        viewModel.actionMessage = "已点赞 👍"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            viewModel.actionMessage = nil
                        }
                    } catch {
                        viewModel.actionMessage = "表情回复: \(error.localizedDescription)"
                    }
                }
            } label: {
                Text("👍")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help("快捷点赞")
            
            // Recall action
            Button {
                Task {
                    do {
                        try await appState.recallMessageItem(message)
                        viewModel.actionMessage = "已撤回"
                    } catch {
                        viewModel.actionMessage = "撤回失败: \(error.localizedDescription)"
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "trash")
                    Text("撤回")
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("撤回此消息 (需权限)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    @ViewBuilder
    private func bubbleContent(content: ParsedMessageContent) -> some View {
        switch content {
        case .text(let text):
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
        case .image(let imageKey):
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
                    .foregroundColor(Color(hex: "3370FF"))
                Text("语音消息")
                    .font(.system(size: 12, weight: .medium))
                if let ms = durationMs {
                    Text("\(ms / 1000)s")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
        case .media(let fileKey, let imageKey, let fileName, let durationSec):
            MessageMediaView(
                messageId: message.messageId,
                fileKey: fileKey,
                imageKey: imageKey,
                fileName: fileName,
                durationSec: durationSec
            )
            .padding(8)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
        case .post(let title, let segments):
            VStack(alignment: .leading, spacing: 6) {
                if let title = title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    renderPostSegment(segment)
                }
            }
            .padding(12)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
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
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
        case .shareChat(let chatId):
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Color(hex: "3370FF"))
                Text("分享群聊 (Chat ID: \(chatId.prefix(12))...)")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
        case .rawText(let raw):
            Text(raw)
                .font(.system(size: 12))
                .padding(10)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
        default:
            Text("不支持的消息类型: \(message.msgType)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(8)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    @ViewBuilder
    private func renderPostSegment(_ segment: PostSegment) -> some View {
        switch segment {
        case .text(let text):
            Text(text)
                .font(.system(size: 13))
                .textSelection(.enabled)
        case .link(let text, let url):
            if let linkUrl = URL(string: url) {
                Link(text, destination: linkUrl)
                    .font(.system(size: 13))
            } else {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "3370FF"))
            }
        case .mention(let name):
            Text("@\(name)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "3370FF"))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(hex: "3370FF").opacity(0.12))
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
    
    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
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
