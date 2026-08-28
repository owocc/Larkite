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

/// Flow Layout for automatic horizontal wrapping of reaction pills
public struct ReactionFlowLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    public var alignment: HorizontalAlignment
    
    public init(spacing: CGFloat = 4, lineSpacing: CGFloat = 4, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentX - spacing)
        }
        
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var rows: [[(subview: LayoutSubview, size: CGSize)]] = [[]]
        var currentX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                rows.append([])
                currentX = 0
            }
            rows[rows.count - 1].append((subview, size))
            currentX += size.width + spacing
        }
        
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            let rowWidth = row.reduce(0) { $0 + $1.size.width } + CGFloat(max(0, row.count - 1)) * spacing
            var x: CGFloat = {
                switch alignment {
                case .trailing:
                    return bounds.maxX - rowWidth
                case .center:
                    return bounds.minX + (width - rowWidth) / 2.0
                default:
                    return bounds.minX
                }
            }()
            
            for item in row {
                item.subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }
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
    let maxBubbleWidth: CGFloat
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init(
        message: FeishuMessageItem,
        isCurrentUser: Bool = false,
        showSenderHeader: Bool = true,
        showTime: Bool = true,
        position: BubbleClusterPosition = .single,
        maxBubbleWidth: CGFloat = 520
    ) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self.showSenderHeader = showSenderHeader
        self.showTime = showTime
        self.position = position
        self.maxBubbleWidth = maxBubbleWidth
    }
    
    public static func == (lhs: MessageBubbleView, rhs: MessageBubbleView) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.updateTime == rhs.message.updateTime &&
        lhs.isCurrentUser == rhs.isCurrentUser &&
        lhs.showSenderHeader == rhs.showSenderHeader &&
        lhs.showTime == rhs.showTime &&
        lhs.position == rhs.position &&
        lhs.maxBubbleWidth == rhs.maxBubbleWidth &&
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
            Spacer(minLength: 20)
            
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
                
                // Bubble Content with Max Width Constraint (80% of window)
                bubbleContent(content: content, isSelf: true)
                    .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
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
                await appState.loadReactions(for: message.messageId)
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
                // Bubble Content with Max Width Constraint (80% of window)
                bubbleContent(content: content, isSelf: false)
                    .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                    .contextMenu {
                        messageContextMenu(content: content, isSelf: false)
                    }
            }
            
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, showSenderHeader ? 2 : 1)
        .frame(minHeight: showSenderHeader || showTime ? 36 : 28, alignment: .leading)
        .onAppear {
            Task {
                await appState.loadReadReceipts(for: message.messageId)
                await appState.loadReactions(for: message.messageId)
            }
        }
    }
    // MARK: - Native Right-Click Context Menu for Reactions & Actions
    
    // MARK: - Reaction Badges View (Matching reference image 52b51ef27af20661.png)
    
    // MARK: - In-Bubble Reaction Badges View (Matching reference image 323446f68c5135ba.png)
    
    private func inBubbleReactionsView(isSelf: Bool) -> some View {
        let grouped = appState.groupedReactions(for: message.messageId)
        return Group {
            if !grouped.isEmpty {
                ReactionFlowLayout(spacing: 4, lineSpacing: 4, alignment: .leading) {
                    ForEach(grouped) { group in
                        Button {
                            if group.count >= 5 {
                                appState.inspectingReactionMessage = message
                            } else {
                                Task {
                                    await appState.toggleReaction(message: message, emojiType: group.emojiType)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(group.emojiChar)
                                    .font(.system(size: 11.5))
                                
                                // Overlapping circular mini avatars
                                HStack(spacing: -5) {
                                    ForEach(Array(group.userIds.prefix(3).enumerated()), id: \.offset) { _, uid in
                                        let name = UserProfileManager.shared.resolveDisplayName(
                                            for: uid,
                                            currentUserId: appState.session?.user?.userId,
                                            currentOpenId: appState.session?.user?.openId
                                        )
                                        let avatar = UserProfileManager.shared.resolveAvatarUrl(for: uid)
                                        AvatarView(urlString: avatar, name: name, size: 15)
                                            .clipShape(Circle())
                                    }
                                }
                                
                                if group.count > 3 {
                                    Text("+\(group.count - 3)")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .windowBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("\(group.emojiName): \(group.userIds.map { UserProfileManager.shared.resolveDisplayName(for: $0, currentUserId: appState.session?.user?.userId, currentOpenId: appState.session?.user?.openId) }.joined(separator: ", "))")
                        .contextMenu {
                            Button("查看详细回应人 (\(group.count) 人)") {
                                appState.inspectingReactionMessage = message
                            }
                            if group.isReactedByMe {
                                Button("取消回应 \(group.emojiChar)") {
                                    Task {
                                        await appState.toggleReaction(message: message, emojiType: group.emojiType)
                                    }
                                }
                            } else {
                                Button("回应 \(group.emojiChar)") {
                                    Task {
                                        await appState.toggleReaction(message: message, emojiType: group.emojiType)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Native Right-Click Context Menu (Matching reference image aba1a426446c0ecf.png)
    
    @ViewBuilder
    private func messageContextMenu(content: ParsedMessageContent, isSelf: Bool) -> some View {
        // Section 1: Top Preset Tapback Emoji Rows
        Section("快速表情回应 (Tapback)") {
            Button("❤️ 爱心") { sendReaction("HEART") }
            Button("👍 点赞") { sendReaction("THUMBSUP") }
            Button("👎 踩") { sendReaction("THUMBSDOWN") }
            Button("😂 破涕为笑") { sendReaction("JOY") }
            Button("‼️ 惊叹") { sendReaction("EXCLAMATION") }
            Button("❓ 疑问") { sendReaction("QUESTION") }
            Button("👀 吃瓜围观") { sendReaction("EYES") }
            Button("🙄 偷笑") { sendReaction("FACEWITHROLLINGEYES") }
            Button("😲 震惊") { sendReaction("ASTONISHED") }
            Button("🎉 庆祝") { sendReaction("PARTY") }
            Button("🔥 太火了") { sendReaction("FIRE") }
            Button("👏 鼓掌") { sendReaction("APPLAUD") }
            
            Menu("更多表情回应...") {
                ForEach(FeishuEmojiHelper.standardEmojis.dropFirst(12), id: \.key) { item in
                    Button("\(item.emoji) \(item.name)") {
                        sendReaction(item.key)
                    }
                }
            }
        }
        
        Divider()
        
        // Section 2: Reply & Common Content Actions
        Button {
            appState.replyingToMessage = message
        } label: {
            Label("回复此消息", systemImage: "arrowshape.turn.up.left")
        }
        
        // Media Specific Actions (Images & Files)
        switch content {
        case .text(let text, _):
            Button {
                copyToClipboard(text: text)
            } label: {
                Label("复制文本内容", systemImage: "doc.on.doc")
            }
        case .image(let imageKey):
            Button {
                previewImageInSystem(imageKey: imageKey)
            } label: {
                Label("快速查看图片 (空格键)", systemImage: "eye")
            }
            
            Button {
                downloadImageToDownloads(imageKey: imageKey)
            } label: {
                Label("在访达中显示 / 下载", systemImage: "folder")
            }
            
            Button {
                copyImageToClipboard(imageKey: imageKey)
            } label: {
                Label("复制图片", systemImage: "photo.on.rectangle")
            }
            
        case .file(let fileKey, let fileName, _):
            Button {
                previewFileInSystem(fileKey: fileKey, fileName: fileName)
            } label: {
                Label("快速查看文件 (空格键)", systemImage: "eye")
            }
            
            Button {
                downloadFileToDownloads(fileKey: fileKey, fileName: fileName)
            } label: {
                Label("在访达中显示 / 下载", systemImage: "folder")
            }
            
        default:
            EmptyView()
        }
        
        Button {
            copyToClipboard(text: message.messageId)
        } label: {
            Label("复制 Message ID", systemImage: "number")
        }
        
        Divider()
        
        // Section 2.5: Share & Multi-Select Easter Egg
        Button {
            if let chat = appState.selectedChat {
                appState.shareSingleMessage(message, chat: chat)
            }
        } label: {
            Label("生成消息卡片分享", systemImage: "photo.stack")
        }
        
        Button {
            appState.enterMultiSelectMode(preselecting: message.messageId)
        } label: {
            Label("多选消息并分享...", systemImage: "checkmark.circle")
        }
        
        Divider()
        // Section 3: Read Receipts & Reaction Details
        Button {
            Task {
                await appState.inspectReadUsers(for: message)
            }
        } label: {
            Label("查看详细已读人 (\(appState.readReceipts[message.messageId]?.readCount ?? 0) 人已读)", systemImage: "eye.fill")
        }
        
        let reactionCount = appState.messageReactions[message.messageId]?.count ?? 0
        if reactionCount > 0 {
            Button {
                appState.inspectingReactionMessage = message
            } label: {
                Label("查看表情回应详情 (\(reactionCount) 人已回应)", systemImage: "face.smiling")
            }
        }
        
        if !isSelf, let senderId = message.sender?.id {
            Divider()
            
            if !(appState.selectedChat?.isP2P ?? true) {
                Button {
                    appState.pendingMentionUser = DraftMentionTarget(id: senderId, name: senderDisplayName)
                } label: {
                    Label("@ 提醒此人", systemImage: "at")
                }
            }
            
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
    }
    
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func sendReaction(_ type: String) {
        Task {
            await appState.toggleReaction(message: message, emojiType: type)
        }
    }
    
    private func previewImageInSystem(imageKey: String) {
        guard let token = appState.session?.accessToken, !token.isEmpty else { return }
        Task {
            try? await MessageResourceManager.shared.previewImage(token: token, messageId: message.messageId, imageKey: imageKey)
        }
    }
    
    private func downloadImageToDownloads(imageKey: String) {
        guard let token = appState.session?.accessToken, !token.isEmpty else { return }
        Task {
            _ = try? await MessageResourceManager.shared.downloadAndSaveImage(token: token, messageId: message.messageId, imageKey: imageKey)
        }
    }
    
    private func copyImageToClipboard(imageKey: String) {
        let cacheKey = "\(message.messageId)_\(imageKey)"
        if let cached = MessageResourceManager.shared.getCachedImage(key: cacheKey),
           let tiff = cached.tiffRepresentation {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(tiff, forType: .tiff)
        }
    }
    
    private func previewFileInSystem(fileKey: String, fileName: String) {
        guard let token = appState.session?.accessToken, !token.isEmpty else { return }
        Task {
            try? await MessageResourceManager.shared.previewFile(token: token, messageId: message.messageId, fileKey: fileKey, fileName: fileName)
        }
    }
    
    private func downloadFileToDownloads(fileKey: String, fileName: String) {
        guard let token = appState.session?.accessToken, !token.isEmpty else { return }
        Task {
            _ = try? await MessageResourceManager.shared.downloadAndSaveFile(token: token, messageId: message.messageId, fileKey: fileKey, fileName: fileName)
        }
    }
    
    @ViewBuilder
    private func bubbleContent(content: ParsedMessageContent, isSelf: Bool) -> some View {
        switch content {
        case .text(_, let segments):
            VStack(alignment: .leading, spacing: 4) {
                renderRichTextSegments(segments, isSelf: isSelf)
                
                inBubbleReactionsView(isSelf: isSelf)
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
            
        case .image(let imageKey):
            VStack(alignment: .leading, spacing: 4) {
                MessageImageView(messageId: message.messageId, imageKey: imageKey)
                inBubbleReactionsView(isSelf: isSelf)
            }
            
        case .file(let fileKey, let fileName, let fileSize):
            VStack(alignment: .leading, spacing: 4) {
                MessageFileView(
                    messageId: message.messageId,
                    fileKey: fileKey,
                    fileName: fileName,
                    fileSize: fileSize
                )
                inBubbleReactionsView(isSelf: isSelf)
            }
            
        case .audio(_, let durationMs):
            VStack(alignment: .leading, spacing: 4) {
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
                inBubbleReactionsView(isSelf: isSelf)
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
            VStack(alignment: .leading, spacing: 4) {
                MessageMediaView(
                    messageId: message.messageId,
                    fileKey: fileKey,
                    imageKey: imageKey,
                    fileName: fileName,
                    durationSec: durationSec
                )
                inBubbleReactionsView(isSelf: isSelf)
            }
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
                
                inBubbleReactionsView(isSelf: isSelf)
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
                
                inBubbleReactionsView(isSelf: isSelf)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appleMessagesIncomingBubble)
            )
            
        case .shareChat(let chatId):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("分享群聊 (Chat ID: \(chatId.prefix(12))...)")
                        .font(.system(size: 12, weight: .medium))
                }
                inBubbleReactionsView(isSelf: isSelf)
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
    private func renderRichTextSegments(_ segments: [PostSegment], isSelf: Bool) -> some View {
        if segments.count == 1, case .text(let t) = segments[0] {
            Text(t)
                .font(.system(size: 13.5))
                .foregroundColor(isSelf ? .white : .primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: maxBubbleWidth - 36, alignment: .leading)
        } else {
            ReactionFlowLayout(spacing: 3, lineSpacing: 3, alignment: .leading) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    renderPostSegment(seg, isSelf: isSelf)
                }
            }
            .frame(maxWidth: maxBubbleWidth - 36, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func renderPostSegment(_ segment: PostSegment, isSelf: Bool) -> some View {
        switch segment {
        case .text(let text):
            Text(text)
                .font(.system(size: 13.5))
                .foregroundColor(isSelf ? .white : .primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                
        case .link(let text, let url):
            if let linkUrl = URL(string: url) {
                Link(text, destination: linkUrl)
                    .font(.system(size: 13.5))
                    .foregroundColor(isSelf ? .white.opacity(0.9) : Color(hex: "3370FF"))
                    .underline()
            } else {
                Text(text)
                    .font(.system(size: 13.5))
                    .foregroundColor(isSelf ? .white.opacity(0.9) : Color(hex: "3370FF"))
            }
            
        case .mention(let id, let name):
            Button {
                if let uid = id, !uid.isEmpty, uid != "all" {
                    Task {
                        await appState.inspectUser(openId: uid, fallbackName: name)
                    }
                }
            } label: {
                Text("@\(name)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(isSelf ? .white : configManager.accentColorChoice.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isSelf ? Color.white.opacity(0.25) : configManager.accentColorChoice.color.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
            .help(id != nil && id != "all" ? "点击查看「\(name)」的详细资料" : "@\(name)")
            
        case .image(let imageKey):
            MessageImageView(messageId: message.messageId, imageKey: imageKey)
            
        case .lineBreak:
            Color.clear
                .frame(width: 9999, height: 4)
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
