import SwiftUI

@MainActor
public final class ChatRowViewModel: ObservableObject {
    @Published public var isHovered: Bool = false
    public init() {}
}

public struct ChatRowView: View {
    let chat: FeishuChatItem
    let isSelected: Bool
    
    @StateObject private var viewModel = ChatRowViewModel()
    
    public init(chat: FeishuChatItem, isSelected: Bool) {
        self.chat = chat
        self.isSelected = isSelected
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(
                urlString: chat.avatar,
                name: chat.displayName,
                size: 40
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(chat.displayName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if chat.isP2P {
                        StatusBadge("私聊", color: Color.teal, icon: "person.fill")
                    } else if chat.isExternal {
                        StatusBadge("外部", color: Color(hex: "FF9C00"))
                    }
                    
                    if chat.isDissolved {
                        StatusBadge("已解散", color: Color.red)
                    }
                }
                
                if let desc = chat.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("ID: \(chat.chatId)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .onHover { hovering in
            viewModel.isHovered = hovering
        }
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
