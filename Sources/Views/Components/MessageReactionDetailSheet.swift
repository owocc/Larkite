import SwiftUI
import AppKit

@MainActor
public final class MessageReactionDetailViewModel: ObservableObject {
    @Published public var selectedEmojiFilter: String? = nil
    
    public init() {}
}

public struct MessageReactionDetailSheet: View {
    let message: FeishuMessageItem
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = MessageReactionDetailViewModel()
    
    public init(message: FeishuMessageItem) {
        self.message = message
    }
    
    private var allReactions: [FeishuReactionItem] {
        appState.messageReactions[message.messageId] ?? []
    }
    
    private var grouped: [GroupedReaction] {
        appState.groupedReactions(for: message.messageId)
    }
    
    private var filteredReactions: [FeishuReactionItem] {
        if let filter = viewModel.selectedEmojiFilter {
            return allReactions.filter { $0.emojiType.caseInsensitiveCompare(filter) == .orderedSame }
        }
        return allReactions
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "face.smiling.fill")
                        .foregroundColor(configManager.accentColorChoice.color)
                    Text("表情回应详情")
                        .font(.system(size: 14, weight: .bold))
                }
                
                Spacer()
                
                Button("完成") {
                    appState.inspectingReactionMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Emoji Category Filter Tabs
            if !grouped.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button {
                            viewModel.selectedEmojiFilter = nil
                        } label: {
                            HStack(spacing: 4) {
                                Text("全部")
                                    .font(.system(size: 11, weight: viewModel.selectedEmojiFilter == nil ? .bold : .medium))
                                Text("\(allReactions.count)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(viewModel.selectedEmojiFilter == nil ? configManager.accentColorChoice.color.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.4))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(viewModel.selectedEmojiFilter == nil ? configManager.accentColorChoice.color.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(grouped) { group in
                            Button {
                                viewModel.selectedEmojiFilter = group.emojiType
                            } label: {
                                HStack(spacing: 4) {
                                    Text(group.emojiChar)
                                        .font(.system(size: 13))
                                    Text("\(group.count)")
                                        .font(.system(size: 11, weight: viewModel.selectedEmojiFilter == group.emojiType ? .bold : .medium))
                                        .foregroundColor(viewModel.selectedEmojiFilter == group.emojiType ? configManager.accentColorChoice.color : .primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(viewModel.selectedEmojiFilter == group.emojiType ? configManager.accentColorChoice.color.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.4))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(viewModel.selectedEmojiFilter == group.emojiType ? configManager.accentColorChoice.color.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                Divider()
            }
            
            // Reaction User List
            if filteredReactions.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "face.dashed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无表情回应")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredReactions) { reaction in
                            let name = UserProfileManager.shared.resolveDisplayName(
                                for: reaction.userId,
                                currentUserId: appState.session?.user?.userId,
                                currentOpenId: appState.session?.user?.openId
                            )
                            let avatar = UserProfileManager.shared.resolveAvatarUrl(for: reaction.userId)
                            let emojiChar = FeishuEmojiHelper.emoji(for: reaction.emojiType)
                            let isMe = (reaction.userId == appState.session?.user?.openId || reaction.userId == appState.session?.user?.userId)
                            
                            HStack(spacing: 10) {
                                AvatarView(urlString: avatar, name: name, size: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        if isMe {
                                            Text("(我)")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(configManager.accentColorChoice.color)
                                        }
                                    }
                                    
                                    if !reaction.formattedActionTime.isEmpty {
                                        Text("回应于 \(reaction.formattedActionTime)")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(emojiChar)
                                    .font(.system(size: 20))
                                    .padding(4)
                                    .background(
                                        Circle()
                                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                    )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(width: 380, height: 420)
        .onAppear {
            Task {
                await appState.loadReactions(for: message.messageId)
            }
        }
    }
}
