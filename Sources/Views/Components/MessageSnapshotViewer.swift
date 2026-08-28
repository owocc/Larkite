import SwiftUI
import AppKit

public enum SnapshotCardTheme: String, CaseIterable, Identifiable, Sendable {
    case sunset = "落日"
    case ocean = "海洋"
    case mint = "薄荷"
    case aurora = "极光"
    case midnight = "暗夜"
    
    public var id: String { rawValue }
    
    public var gradient: LinearGradient {
        switch self {
        case .sunset:
            return LinearGradient(
                colors: [Color(hex: "5856D6"), Color(hex: "FF2D55"), Color(hex: "FF9500")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            return LinearGradient(
                colors: [Color(hex: "00C0FF"), Color(hex: "3370FF"), Color(hex: "0040C0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mint:
            return LinearGradient(
                colors: [Color(hex: "30D158"), Color(hex: "00C7BE"), Color(hex: "3370FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .aurora:
            return LinearGradient(
                colors: [Color(hex: "7838FF"), Color(hex: "3370FF"), Color(hex: "00E5FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnight:
            return LinearGradient(
                colors: [Color(hex: "1C1C1E"), Color(hex: "2C2C2E"), Color(hex: "0A0A0C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    public var previewColor: Color {
        switch self {
        case .sunset: return Color(hex: "FF2D55")
        case .ocean: return Color(hex: "3370FF")
        case .mint: return Color(hex: "30D158")
        case .aurora: return Color(hex: "7838FF")
        case .midnight: return Color(hex: "2C2C2E")
        }
    }
}

@MainActor
public final class MessageSnapshotViewerViewModel: ObservableObject {
    @Published public var selectedTheme: SnapshotCardTheme = .sunset
    @Published public var showUIFrame: Bool = false
    @Published public var showChatTitle: Bool = true
    @Published public var showSenderNames: Bool = true
    @Published public var showTimestamps: Bool = true
    @Published public var showWatermark: Bool = true
    
    @Published public var isRendering: Bool = false
    @Published public var actionToast: String? = nil
    
    public init() {}
    
    public func showToast(_ msg: String) {
        self.actionToast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.actionToast == msg {
                self?.actionToast = nil
            }
        }
    }
}

public struct MessageSnapshotViewer: View {
    let messages: [FeishuMessageItem]
    let chat: FeishuChatItem
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = MessageSnapshotViewerViewModel()
    
    public init(messages: [FeishuMessageItem], chat: FeishuChatItem) {
        self.messages = messages
        self.chat = chat
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Scrollable Card Preview Area
            ScrollView([.vertical, .horizontal]) {
                VStack {
                    cardContent
                        .padding(28)
                }
                .frame(maxWidth: .infinity, minHeight: 480)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            // Bottom Controls Bar: Themes + Customization Options + Action Buttons
            bottomToolbarView
        }
        .frame(minWidth: 640, minHeight: 640)
    }
    
    // MARK: - Bottom Controls Bar (Fixed Single Line, No Wrapping)
    
    private var bottomToolbarView: some View {
        HStack(spacing: 10) {
            // 1. Theme Selector Pills (Whole Pill Clickable)
            HStack(spacing: 5) {
                Text("主题:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .fixedSize()
                    .lineLimit(1)
                
                ForEach(SnapshotCardTheme.allCases) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectedTheme = theme
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.previewColor)
                                .frame(width: 8, height: 8)
                            Text(theme.rawValue)
                                .font(.system(size: 11, weight: viewModel.selectedTheme == theme ? .bold : .medium))
                                .fixedSize()
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedTheme == theme ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(viewModel.selectedTheme == theme ? configManager.accentColorChoice.color.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                    .fixedSize()
                }
            }
            
            // 2. Customization Menu (UI Frame, Title, Names, Timestamps, Watermark)
            Menu {
                Toggle("显示 UI 卡片框架", isOn: $viewModel.showUIFrame)
                Divider()
                Toggle("显示会话标题", isOn: $viewModel.showChatTitle)
                Toggle("显示发信人名称", isOn: $viewModel.showSenderNames)
                Toggle("显示消息时间", isOn: $viewModel.showTimestamps)
                Toggle("显示底部水印", isOn: $viewModel.showWatermark)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                    Text("卡片选项")
                        .font(.system(size: 11, weight: .medium))
                        .fixedSize()
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.8)
                )
                .contentShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("自定义卡片框架、标题、时间戳与水印展示")
            
            Spacer(minLength: 8)
            
            if let toast = viewModel.actionToast {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "34C759"))
                    .fixedSize()
                    .lineLimit(1)
                    .transition(.opacity)
            }
            
            // 3. Action Buttons (SF Symbols, No Emoji)
            Button {
                copyCardImage()
            } label: {
                Label("复制图片", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .fixedSize()
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize()
            .help("将生成的卡片长图复制到系统剪贴板")
            
            Button {
                saveCardImage()
            } label: {
                Label("保存长图", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .fixedSize()
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .fixedSize()
            .help("导出高分辨率 PNG 长图并保存至下载文件夹")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Message Snapshot Card View (Zero Shadow, Pure Clean Flat Design)
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Outer Theme Gradient Container
            VStack(spacing: 0) {
                if viewModel.showUIFrame {
                    // Mode A: Full UI Frame Container (Zero Shadow)
                    VStack(alignment: .leading, spacing: 14) {
                        if viewModel.showChatTitle {
                            // Header: Chat Avatar + Name + Branding Badge
                            HStack(spacing: 10) {
                                AvatarView(
                                    urlString: chat.resolvedAvatarUrl(currentUserId: appState.session?.user?.openId),
                                    name: chat.displayName,
                                    size: 34
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.displayName)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text("会话记录分享 • 共 \(messages.count) 条消息")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "FF9500"))
                                    Text("Larkite")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                                .clipShape(Capsule())
                            }
                            
                            Divider()
                        }
                        
                        // Messages Stream with Consecutive Sender Clustering
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                let prevMsg = index > 0 ? messages[index - 1] : nil
                                let isSameSenderAsPrev = prevMsg != nil && prevMsg?.sender?.id == msg.sender?.id
                                let prevTimeMs = prevMsg.flatMap { Double($0.createTime) } ?? 0
                                let currTimeMs = Double(msg.createTime) ?? 0
                                let timeDiffMins = prevMsg != nil ? abs(currTimeMs - prevTimeMs) / (1000 * 60) : 999
                                let isConsecutive = isSameSenderAsPrev && timeDiffMins < 10
                                
                                snapshotMessageRow(msg, isFlatOnGradient: false, showSenderHeader: !isConsecutive)
                            }
                        }
                        
                        if viewModel.showWatermark {
                            Divider()
                            
                            // Card Footer: Watermark & Date
                            HStack {
                                Text("由 Larkite for macOS 生成")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(currentDateString)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        Color(nsColor: .windowBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
                } else {
                    // Mode B: Pure Clean Message Flow directly on Gradient (Default, No Heavy UI Frame, Zero Shadow)
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.showChatTitle {
                            HStack(spacing: 8) {
                                AvatarView(
                                    urlString: chat.resolvedAvatarUrl(currentUserId: appState.session?.user?.openId),
                                    name: chat.displayName,
                                    size: 26
                                )
                                
                                Text(chat.displayName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("Larkite")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                            .padding(.bottom, 4)
                        }
                        
                        // Messages Stream with Consecutive Sender Clustering
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                let prevMsg = index > 0 ? messages[index - 1] : nil
                                let isSameSenderAsPrev = prevMsg != nil && prevMsg?.sender?.id == msg.sender?.id
                                let prevTimeMs = prevMsg.flatMap { Double($0.createTime) } ?? 0
                                let currTimeMs = Double(msg.createTime) ?? 0
                                let timeDiffMins = prevMsg != nil ? abs(currTimeMs - prevTimeMs) / (1000 * 60) : 999
                                let isConsecutive = isSameSenderAsPrev && timeDiffMins < 10
                                
                                snapshotMessageRow(msg, isFlatOnGradient: true, showSenderHeader: !isConsecutive)
                            }
                        }
                        
                        if viewModel.showWatermark {
                            HStack {
                                Text("由 Larkite for macOS 生成")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.75))
                                
                                Spacer()
                                
                                Text(currentDateString)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(16)
            .background(viewModel.selectedTheme.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(width: 440)
    }
    
    // MARK: - Snapshot Message Item Row (Zero Shadows, Clean Flat Design)
    
    private func snapshotMessageRow(_ msg: FeishuMessageItem, isFlatOnGradient: Bool, showSenderHeader: Bool) -> some View {
        let myOpenId = appState.session?.user?.openId ?? ""
        let myUserId = appState.session?.user?.userId ?? ""
        let isSelf = (msg.sender?.id == myOpenId && !myOpenId.isEmpty) || (msg.sender?.id == myUserId && !myUserId.isEmpty)
        let senderName = UserProfileManager.shared.resolveDisplayName(
            for: msg.sender?.id ?? "",
            currentUserId: appState.session?.user?.userId,
            currentOpenId: appState.session?.user?.openId
        )
        let avatarUrl = UserProfileManager.shared.resolveAvatarUrl(for: msg.sender?.id ?? "")
        let reactions = appState.groupedReactions(for: msg.messageId)
        
        return HStack(alignment: .top, spacing: 8) {
            if !isSelf {
                if showSenderHeader {
                    AvatarView(urlString: avatarUrl, name: senderName, size: 26)
                } else {
                    Color.clear
                        .frame(width: 26, height: 26)
                }
            }
            
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 3) {
                // Header (Name + Time)
                if (viewModel.showSenderNames && !isSelf && showSenderHeader) || viewModel.showTimestamps {
                    HStack(spacing: 4) {
                        if viewModel.showSenderNames && !isSelf && showSenderHeader {
                            Text(senderName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isFlatOnGradient ? .white.opacity(0.9) : .secondary)
                        }
                        
                        if viewModel.showTimestamps {
                            Text(msg.formattedTime)
                                .font(.system(size: 9))
                                .foregroundColor(isFlatOnGradient ? .white.opacity(0.7) : .secondary.opacity(0.8))
                        }
                    }
                }
                
                // Content Rendering (Optimized for Images, Videos, Files, and Texts)
                snapshotContentBody(msg: msg, isSelf: isSelf, isFlatOnGradient: isFlatOnGradient, reactions: reactions)
            }
            
            if isSelf {
                if showSenderHeader {
                    AvatarView(urlString: avatarUrl, name: "我", size: 26)
                } else {
                    Color.clear
                        .frame(width: 26, height: 26)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isSelf ? .trailing : .leading)
    }
    
    // MARK: - Specialized Snapshot Content Body
    
    @ViewBuilder
    private func snapshotContentBody(msg: FeishuMessageItem, isSelf: Bool, isFlatOnGradient: Bool, reactions: [GroupedReaction]) -> some View {
        switch msg.parsedContent {
        case .image(let imageKey):
            // Frameless High-Quality Image with Rounded Corners
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 4) {
                MessageImageView(messageId: msg.messageId, imageKey: imageKey)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                    )
                
                if !reactions.isEmpty {
                    snapshotReactionsPills(reactions)
                }
            }
            
        case .media(_, let imageKey, let fileName, let durationSec):
            // Video Preview Card with Duration Badge
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    if let imgKey = imageKey, !imgKey.isEmpty {
                        MessageImageView(messageId: msg.messageId, imageKey: imgKey)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                                .frame(width: 220, height: 130)
                            
                            Circle()
                                .fill(Color.black.opacity(0.55))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .offset(x: 1)
                                )
                        }
                    }
                    
                    if let sec = durationSec, sec > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text(String(format: "%02d:%02d", sec / 60, sec % 60))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                        .padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                )
                
                if !reactions.isEmpty {
                    snapshotReactionsPills(reactions)
                }
            }
            
        case .file(_, let fileName, let fileSize):
            // macOS Native Rich File Card with Color-Coded Icon
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(snapshotFileColor(for: fileName).opacity(0.18))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: snapshotFileIcon(for: fileName))
                            .font(.system(size: 18))
                            .foregroundColor(snapshotFileColor(for: fileName))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if let size = fileSize {
                            Text(formattedFileSize(bytes: size))
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary.opacity(0.65))
                }
                .padding(10)
                .frame(width: 250)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelf ? (isFlatOnGradient ? Color.white.opacity(0.95) : Color(nsColor: .controlBackgroundColor).opacity(0.6)) : (isFlatOnGradient ? Color.white.opacity(0.95) : Color.appleMessagesIncomingBubble))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.8)
                )
                
                if !reactions.isEmpty {
                    snapshotReactionsPills(reactions)
                }
            }
            
        case .text(let text):
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 12.5))
                    .foregroundColor(isSelf ? .white : .primary)
                    .multilineTextAlignment(.leading)
                
                if !reactions.isEmpty {
                    snapshotReactionsPills(reactions)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelf ? configManager.accentColorChoice.color : (isFlatOnGradient ? Color.white.opacity(0.94) : Color.appleMessagesIncomingBubble))
            )
            
        case .audio(_, let durationMs):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 15))
                        .foregroundColor(isSelf ? .white : Color(hex: "3370FF"))
                    Text("语音消息")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(isSelf ? .white : .primary)
                    if let ms = durationMs {
                        Text("\(ms / 1000)s")
                            .font(.system(size: 10))
                            .foregroundColor(isSelf ? .white.opacity(0.8) : .secondary)
                    }
                }
                
                if !reactions.isEmpty {
                    snapshotReactionsPills(reactions)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelf ? configManager.accentColorChoice.color : (isFlatOnGradient ? Color.white.opacity(0.94) : Color.appleMessagesIncomingBubble))
            )
            
        case .post(let title, let segments):
            VStack(alignment: .leading, spacing: 4) {
                if let title = title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isSelf ? .white : .primary)
                }
                
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let t):
                        Text(t)
                            .font(.system(size: 12))
                            .foregroundColor(isSelf ? .white : .primary)
                    case .link(let t, _):
                        Text(t)
                            .font(.system(size: 12))
                            .foregroundColor(isSelf ? .white.opacity(0.9) : Color(hex: "3370FF"))
                            .underline()
                    default:
                        EmptyView()
                    }
                }
                
                if !reactions.isEmpty {
                    snapshotReactionsPills(reactions)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelf ? configManager.accentColorChoice.color : (isFlatOnGradient ? Color.white.opacity(0.94) : Color.appleMessagesIncomingBubble))
            )
            
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.parsedContent.previewSummary)
                    .font(.system(size: 11))
                    .foregroundColor(isSelf ? .white : .primary)
                
                if !reactions.isEmpty {
                    snapshotReactionsPills(reactions)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelf ? configManager.accentColorChoice.color : (isFlatOnGradient ? Color.white.opacity(0.94) : Color.appleMessagesIncomingBubble))
            )
        }
    }
    
    private func snapshotReactionsPills(_ reactions: [GroupedReaction]) -> some View {
        HStack(spacing: 4) {
            ForEach(reactions) { r in
                HStack(spacing: 2) {
                    Text(r.emojiChar)
                        .font(.system(size: 10))
                    if r.count > 1 {
                        Text("\(r.count)")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)))
            }
        }
        .padding(.top, 2)
    }
    
    private func snapshotFileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text.fill"
        case "zip", "tar", "gz", "7z", "rar": return "doc.zipper"
        case "doc", "docx", "pages": return "doc.richtext.fill"
        case "xls", "xlsx", "numbers", "csv": return "tablecells.fill"
        case "ppt", "pptx", "key": return "play.rectangle.fill"
        case "mp3", "wav", "m4a", "flac", "aac": return "music.note"
        case "mp4", "mov", "avi", "mkv", "webm": return "film.fill"
        case "png", "jpg", "jpeg", "webp", "gif", "heic": return "photo.fill"
        case "swift", "js", "ts", "py", "json", "html", "css", "c", "cpp", "go", "rs": return "curlybraces"
        default: return "doc.fill"
        }
    }

    private func snapshotFileColor(for fileName: String) -> Color {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return .red
        case "zip", "tar", "gz", "7z", "rar": return .purple
        case "doc", "docx", "pages": return Color(hex: "3370FF")
        case "xls", "xlsx", "numbers", "csv": return .green
        case "ppt", "pptx", "key": return .orange
        case "mp3", "wav", "m4a", "flac": return .pink
        case "mp4", "mov", "avi", "mkv": return .indigo
        default: return .secondary
        }
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
    
    private func formattedFileSize(bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }
    
    // MARK: - Image Export Actions
    
    private func renderCardImage() -> NSImage? {
        let renderer = ImageRenderer(content: cardContent)
        renderer.scale = 2.0
        return renderer.nsImage
    }
    
    private func copyCardImage() {
        guard let img = renderCardImage() else {
            viewModel.showToast("生成图片失败")
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let tiff = img.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
            viewModel.showToast("✓ 已复制长图到剪贴板")
        }
    }
    
    private func saveCardImage() {
        guard let img = renderCardImage() else {
            viewModel.showToast("生成图片失败")
            return
        }
        guard let tiffData = img.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            viewModel.showToast("转换 PNG 格式失败")
            return
        }
        
        let downloadsUrl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileUrl = downloadsUrl.appendingPathComponent("Larkite_Snapshot_\(timestamp).png")
        
        do {
            try pngData.write(to: fileUrl)
            viewModel.showToast("✓ 已保存至下载文件夹")
            NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
        } catch {
            viewModel.showToast("保存失败: \(error.localizedDescription)")
        }
    }
}
