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

public enum BubbleClusterPosition: String, Equatable, Sendable {
    case single
    case first
    case middle
    case last
}

/// Native Apple Messages Chat Bubble Shape with bottom-left and bottom-right tail curves
/// and dynamic corner radii according to cluster position (first, middle, last, single)
public struct ChatBubbleShape: Shape {
    public let isSelf: Bool
    public let position: BubbleClusterPosition
    
    public init(isSelf: Bool, position: BubbleClusterPosition = .single) {
        self.isSelf = isSelf
        self.position = position
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let rLarge: CGFloat = 16
        let rSmall: CGFloat = 4
        let tailW: CGFloat = 5
        let tailH: CGFloat = 6
        
        let hasTail = (position == .single || position == .last)
        
        if isSelf {
            // Outgoing message (Right-aligned):
            // Body right edge is at (rect.maxX - tailW) for all messages, so all messages have identical right alignment
            let bMaxX = rect.maxX - tailW
            let bMinX = rect.minX
            let bMinY = rect.minY
            let bMaxY = rect.maxY
            
            let rTL: CGFloat = rLarge
            let rBL: CGFloat = rLarge
            // Top-Right is rSmall (4) for .middle and .last; rLarge (16) for .single and .first
            let rTR: CGFloat = (position == .middle || position == .last) ? rSmall : rLarge
            // Bottom-Right is rSmall (4) for .first and .middle; Tail for .single and .last
            let rBR: CGFloat = (position == .first || position == .middle) ? rSmall : rLarge
            
            // Start at Top-Left after arc
            path.move(to: CGPoint(x: bMinX + rTL, y: bMinY))
            
            // Top edge & Top-Right corner
            path.addLine(to: CGPoint(x: bMaxX - rTR, y: bMinY))
            path.addArc(center: CGPoint(x: bMaxX - rTR, y: bMinY + rTR), radius: rTR, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            
            if hasTail {
                // Right edge down to tail start
                path.addLine(to: CGPoint(x: bMaxX, y: bMaxY - tailH - 4))
                // Tail curve out to bottom-right tip
                path.addCurve(
                    to: CGPoint(x: rect.maxX, y: bMaxY),
                    control1: CGPoint(x: bMaxX, y: bMaxY - 2),
                    control2: CGPoint(x: rect.maxX - 1, y: bMaxY)
                )
                // Tail curve in to bottom edge
                path.addCurve(
                    to: CGPoint(x: bMaxX - 12, y: bMaxY),
                    control1: CGPoint(x: rect.maxX - 3, y: bMaxY),
                    control2: CGPoint(x: bMaxX - 6, y: bMaxY)
                )
            } else {
                // Right edge down & Bottom-Right corner (rBR is rSmall = 4)
                path.addLine(to: CGPoint(x: bMaxX, y: bMaxY - rBR))
                path.addArc(center: CGPoint(x: bMaxX - rBR, y: bMaxY - rBR), radius: rBR, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            }
            
            // Bottom edge to Bottom-Left corner
            path.addLine(to: CGPoint(x: bMinX + rBL, y: bMaxY))
            path.addArc(center: CGPoint(x: bMinX + rBL, y: bMaxY - rBL), radius: rBL, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            
            // Left edge up & Top-Left corner
            path.addLine(to: CGPoint(x: bMinX, y: bMinY + rTL))
            path.addArc(center: CGPoint(x: bMinX + rTL, y: bMinY + rTL), radius: rTL, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            
        } else {
            // Incoming message (Left-aligned):
            // Body left edge is at (rect.minX + tailW) for all messages, so all messages have identical left margin
            let bMinX = rect.minX + tailW
            let bMaxX = rect.maxX
            let bMinY = rect.minY
            let bMaxY = rect.maxY
            
            let rTR: CGFloat = rLarge
            let rBR: CGFloat = rLarge
            // Top-Left is rSmall (4) for .middle and .last; rLarge (16) for .single and .first
            let rTL: CGFloat = (position == .middle || position == .last) ? rSmall : rLarge
            // Bottom-Left is rSmall (4) for .first and .middle; Tail for .single and .last
            let rBL: CGFloat = (position == .first || position == .middle) ? rSmall : rLarge
            
            // Start at Top-Left after arc
            path.move(to: CGPoint(x: bMinX + rTL, y: bMinY))
            
            // Top edge & Top-Right corner
            path.addLine(to: CGPoint(x: bMaxX - rTR, y: bMinY))
            path.addArc(center: CGPoint(x: bMaxX - rTR, y: bMinY + rTR), radius: rTR, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            
            // Right edge down & Bottom-Right corner
            path.addLine(to: CGPoint(x: bMaxX, y: bMaxY - rBR))
            path.addArc(center: CGPoint(x: bMaxX - rBR, y: bMaxY - rBR), radius: rBR, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            
            if hasTail {
                // Bottom edge to tail start
                path.addLine(to: CGPoint(x: bMinX + 12, y: bMaxY))
                // Tail curve out to bottom-left tip
                path.addCurve(
                    to: CGPoint(x: rect.minX, y: bMaxY),
                    control1: CGPoint(x: bMinX + 6, y: bMaxY),
                    control2: CGPoint(x: rect.minX + 3, y: bMaxY)
                )
                // Tail curve in to left edge
                path.addCurve(
                    to: CGPoint(x: bMinX, y: bMaxY - tailH - 4),
                    control1: CGPoint(x: rect.minX + 1, y: bMaxY),
                    control2: CGPoint(x: bMinX, y: bMaxY - 2)
                )
            } else {
                // Bottom edge to Bottom-Left corner (rBL is rSmall = 4)
                path.addLine(to: CGPoint(x: bMinX + rBL, y: bMaxY))
                path.addArc(center: CGPoint(x: bMinX + rBL, y: bMaxY - rBL), radius: rBL, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            }
            
            // Left edge up & Top-Left corner
            path.addLine(to: CGPoint(x: bMinX, y: bMinY + rTL))
            path.addArc(center: CGPoint(x: bMinX + rTL, y: bMinY + rTL), radius: rTL, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

public struct MessageBubbleView: View, Equatable {
    let message: FeishuMessageItem
    let isCurrentUser: Bool
    let showSenderHeader: Bool
    let showTime: Bool
    let position: BubbleClusterPosition
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init(
        message: FeishuMessageItem,
        isCurrentUser: Bool = false,
        showSenderHeader: Bool = true,
        showTime: Bool = true,
        position: BubbleClusterPosition = .single
    ) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self.showSenderHeader = showSenderHeader
        self.showTime = showTime
        self.position = position
    }
    
    public static func == (lhs: MessageBubbleView, rhs: MessageBubbleView) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.updateTime == rhs.message.updateTime &&
        lhs.isCurrentUser == rhs.isCurrentUser &&
        lhs.showSenderHeader == rhs.showSenderHeader &&
        lhs.showTime == rhs.showTime &&
        lhs.position == rhs.position &&
        lhs.configManager.accentColorChoice == rhs.configManager.accentColorChoice
    }
    
    private var isSelfMessage: Bool {
        if isCurrentUser { return true }
        guard let sender = message.sender else { return false }
        if let current = appState.session?.user {
            return sender.id == current.openId || sender.id == current.userId
        }
        return false
    }
    private var isTailVisible: Bool {
        position == .single || position == .last
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
        let receipt = appState.readReceipts[message.messageId]
        let isP2P = appState.selectedChat?.isP2P ?? true
        let isAllRead = receipt?.isAllRead ?? false || (isP2P && (receipt?.readCount ?? 0) > 0)
        let readCount = receipt?.readCount ?? 0
        
        return HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 48)
            
            VStack(alignment: .trailing, spacing: 6) {
                if showTime {
                    HStack(spacing: 4) {
                        Text(message.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        if isAllRead {
                            // All Read: Double checkmark ✓✓ (matching reference image c6d1c5ecdbaddeaa.png!)
                            HStack(spacing: -5) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(configManager.accentColorChoice.color)
                            .help("全部已读")
                        } else if readCount > 0 {
                            // Partial Read in Group: Eye icon + readCount 👁️ N (matching reference image d800674c2547b3d1.png!)
                            HStack(spacing: 2) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 8))
                                Text("\(readCount)")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .help("\(readCount) 人已读")
                        } else {
                            // Sent / Unread: Single checkmark ✓
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.6))
                                .help("已送达")
                        }
                    }
                    .frame(height: 14)
                }
                
                // Bubble Content with Right-Click Context Menu
                bubbleContent(content: content, isSelf: true)
                    .contextMenu {
                        messageContextMenu(content: content, isSelf: true)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, showSenderHeader ? 2 : 1)
        .frame(minHeight: showTime ? 36 : 28, alignment: .trailing)
        .onAppear {
            Task {
                await appState.loadReadReceipts(for: message.messageId)
            }
        }
    }
    
    // MARK: - Other's Messages (Left Aligned, Apple Messages Grey)
    
    private func otherMessageRow(content: ParsedMessageContent) -> some View {
        let receipt = appState.readReceipts[message.messageId]
        let readCount = receipt?.readCount ?? 0
        let isGroup = !(appState.selectedChat?.isP2P ?? false)
        
        return HStack(alignment: .bottom, spacing: 10) {
            // Sender Avatar (Only shown on cluster tail, otherwise empty placeholder for aligned indent)
            if isTailVisible {
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
            } else {
                Color.clear
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if showSenderHeader || showTime {
                    HStack(spacing: 6) {
                        if showSenderHeader {
                            Text(senderDisplayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if message.sender?.isAppOrBot ?? false {
                                StatusBadge("Bot", color: Color(hex: "7838FF"))
                            }
                        }
                        
                        if showTime {
                            Text(message.formattedTime)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        if isGroup && readCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 8))
                                Text("\(readCount)")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .help("\(readCount) 人已读")
                        }
                    }
                    .frame(height: 14)
                }
                
                // Bubble Content with Right-Click Context Menu
                bubbleContent(content: content, isSelf: false)
                    .contextMenu {
                        messageContextMenu(content: content, isSelf: false)
                    }
            }
            
            Spacer(minLength: 48)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, showSenderHeader ? 2 : 1)
        .frame(minHeight: showSenderHeader || showTime ? 36 : 28, alignment: .leading)
        .onAppear {
            Task {
                await appState.loadReadReceipts(for: message.messageId)
            }
        }
    }
    // MARK: - Native Right-Click Context Menu for Reactions & Actions
    
    @ViewBuilder
    private func messageContextMenu(content: ParsedMessageContent, isSelf: Bool) -> some View {
        Section("回应表情") {
            Button("👍 点赞") {
                sendReaction("THUMBSUP")
            }
            Button("❤️ 爱心") {
                sendReaction("HEART")
            }
            Button("👏 鼓掌") {
                sendReaction("APPLAUD")
            }
            Button("😄 开心") {
                sendReaction("JOY")
            }
            Button("🎉 庆祝") {
                sendReaction("PARTY")
            }
            Button("🔥 火力") {
                sendReaction("FIRE")
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
                copyToClipboard(text: text)
            } label: {
                Label("复制文本内容", systemImage: "doc.on.doc")
            }
        }
        
        Button {
            copyToClipboard(text: message.messageId)
        } label: {
            Label("复制 Message ID", systemImage: "number")
        }
        
        
        Divider()
        
        Button {
            Task {
                await appState.inspectReadUsers(for: message)
            }
        } label: {
            Label("查看详细已读人 (\(appState.readReceipts[message.messageId]?.readCount ?? 0) 人已读)", systemImage: "eye.fill")
        }
        if isSelf {
            Divider()
            Button(role: .destructive) {
                Task {
                    try? await appState.recallMessageItem(message)
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
    
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func sendReaction(_ type: String) {
        Task {
            try? await appState.addReaction(to: message, emojiType: type)
        }
    }
    
    
    @ViewBuilder
    private func bubbleContent(content: ParsedMessageContent, isSelf: Bool) -> some View {
        switch content {
        case .text(let text):
            Text(text)
                .font(.system(size: 13.5))
                .foregroundColor(isSelf ? .white : .primary)
                .padding(.leading, isSelf ? 14 : 19)
                .padding(.trailing, isSelf ? 19 : 14)
                .padding(.vertical, 9)
                .background(
                    ChatBubbleShape(isSelf: isSelf, position: position)
                        .fill(isSelf ? configManager.accentColorChoice.color : Color.appleMessagesIncomingBubble)
                )
                .overlay(
                    ChatBubbleShape(isSelf: isSelf, position: position)
                        .stroke(isSelf ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.8)
                )
        case .image(let imageKey):
            // Apple Messages style: Frameless edge-to-edge image attachment
            MessageImageView(messageId: message.messageId, imageKey: imageKey)
                .contextMenu {
                    Button("复制 Message ID") {
                        copyToClipboard(text: message.messageId)
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
                    copyToClipboard(text: message.messageId)
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
            .padding(.leading, isSelf ? 14 : 19)
            .padding(.trailing, isSelf ? 19 : 14)
            .padding(.vertical, 9)
            .background(
                ChatBubbleShape(isSelf: isSelf, position: position)
                    .fill(isSelf ? configManager.accentColorChoice.color : Color.appleMessagesIncomingBubble)
            )
            .overlay(
                ChatBubbleShape(isSelf: isSelf, position: position)
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
            .padding(.leading, isSelf ? 14 : 19)
            .padding(.trailing, isSelf ? 19 : 14)
            .padding(.vertical, 12)
            .background(
                ChatBubbleShape(isSelf: isSelf, position: position)
                    .fill(isSelf ? configManager.accentColorChoice.color : Color.appleMessagesIncomingBubble)
            )
            .overlay(
                ChatBubbleShape(isSelf: isSelf, position: position)
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
