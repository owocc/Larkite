import SwiftUI
import AppKit

public struct MessageReadUsersSheet: View {
    let message: FeishuMessageItem
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init(message: FeishuMessageItem) {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .foregroundColor(configManager.accentColorChoice.color)
                    Text("消息已读详情")
                        .font(.system(size: 14, weight: .bold))
                }
                
                Spacer()
                
                Button("完成") {
                    appState.inspectingReadReceiptMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Message Summary Card
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("消息内容: \(message.parsedContent.previewSummary)")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("发送时间: \(message.formattedTime)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
            
            Divider()
            
            // Read Users List
            if appState.isLoadingReadUsers && appState.inspectingReadUsers.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("正在查询已读成员清单...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = appState.readReceiptError, appState.inspectingReadUsers.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("无法获取已读详情: \(error)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    Spacer()
                }
            } else if appState.inspectingReadUsers.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "eye.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无成员已读此消息")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("已读成员列表")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(appState.inspectingReadUsers.count) 人已读")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(configManager.accentColorChoice.color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(appState.inspectingReadUsers) { item in
                                let name = UserProfileManager.shared.resolveDisplayName(for: item.userId, currentUserId: appState.session?.user?.openId)
                                let avatar = UserProfileManager.shared.resolveAvatarUrl(for: item.userId)
                                HStack(spacing: 10) {
                                    AvatarView(urlString: avatar, name: name, size: 28)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        if !item.formattedReadTime.isEmpty {
                                            Text("已读于 \(item.formattedReadTime)")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(configManager.accentColorChoice.color)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .frame(width: 380, height: 420)
    }
}
