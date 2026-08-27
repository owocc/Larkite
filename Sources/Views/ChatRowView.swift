import SwiftUI

@MainActor
public final class ChatRowViewModel: ObservableObject {
    @Published public var isHovered: Bool = false
    public init() {}
}

public struct ChatRowView: View {
    let chat: FeishuChatItem
    let isSelected: Bool
    
    @ObservedObject var appState: AppState = .shared
    @StateObject private var viewModel = ChatRowViewModel()
    
    public init(chat: FeishuChatItem, isSelected: Bool) {
        self.chat = chat
        self.isSelected = isSelected
    }
    
    public var body: some View {
        let currentUser = appState.session?.user
        let lastMsg = appState.lastMessages[chat.chatId]
        
        let title = chatTitle(currentUser: currentUser, lastMsg: lastMsg)
        let avatarUrl = chat.resolvedAvatarUrl(currentUserId: currentUser?.openId)
        
        HStack(spacing: 12) {
            // Avatar
            AvatarView(
                urlString: avatarUrl,
                name: title,
                size: 40
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Top Row: Title + Timestamp + Badges
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let msg = lastMsg {
                        Text(msg.formattedTimeOrDate)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    if chat.isP2P {
                        StatusBadge("私聊", color: Color.teal, icon: "person.fill")
                    } else if chat.isExternal {
                        StatusBadge("外部", color: Color(hex: "FF9C00"))
                    }
                    
                    if chat.isDissolved {
                        StatusBadge("已解散", color: Color.red)
                    }
                }
                
                // Bottom Row: Latest Message Snippet with Sender Name
                HStack(spacing: 4) {
                    if let msg = lastMsg {
                        Text(lastMessageSummary(msg: msg, currentUser: currentUser))
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .primary.opacity(0.85) : .secondary)
                            .lineLimit(1)
                    } else if let desc = chat.description, !desc.isEmpty, desc != "单聊会话", desc != currentUser?.displayName {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("暂无新消息")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            viewModel.isHovered = hovering
        }
    }
    
    private func chatTitle(currentUser: FeishuUserInfo?, lastMsg: FeishuMessageItem?) -> String {
        let base = chat.resolvedDisplayName(
            currentUserName: currentUser?.displayName,
            currentUserId: currentUser?.openId
        )
        
        // If chat name is generic "未命名群组 (oc_xxx)", try enriching with sender name if p2p
        if chat.isP2P && base.hasPrefix("未命名群组") {
            if let sender = lastMsg?.sender, sender.id != currentUser?.openId {
                let senderName = UserProfileManager.shared.resolveDisplayName(for: sender.id, currentUserId: currentUser?.openId)
                if !senderName.hasPrefix("用户 (") {
                    return senderName
                }
            }
        }
        
        return base
    }
    
    private func lastMessageSummary(msg: FeishuMessageItem, currentUser: FeishuUserInfo?) -> String {
        let senderName: String = {
            if let mentions = msg.mentions, let first = mentions.first, let name = first.name, !name.isEmpty {
                return name
            }
            if let sender = msg.sender {
                if sender.isAppOrBot {
                    return "机器人"
                }
                let currentUserId = currentUser?.openId
                return UserProfileManager.shared.resolveDisplayName(for: sender.id, currentUserId: currentUserId)
            }
            return "成员"
        }()
        
        let summary = msg.parsedContent.previewSummary
        if summary.isEmpty {
            return "\(senderName): 发送了一条消息"
        }
        return "\(senderName): \(summary)"
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: "3370FF").opacity(0.15)
        }
        if viewModel.isHovered {
            return Color(nsColor: .quaternaryLabelColor).opacity(0.3)
        }
        return Color.clear
    }
}
