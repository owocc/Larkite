import SwiftUI

public struct ChatListView: View {
    @ObservedObject var appState: AppState = .shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header / Search & Filter Section
            headerSection
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
            
            // Content
            if appState.isLoadingChats && appState.chats.isEmpty {
                loadingView
            } else if let error = appState.chatError, appState.chats.isEmpty {
                errorView(error: error)
            } else if appState.filteredChats.isEmpty {
                emptyView
            } else {
                chatListContent
            }
        }
        .frame(minWidth: 280, maxWidth: 360)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Title & Refresh
            HStack {
                Text("消息与群组")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                Button {
                    Task {
                        await appState.loadChats(reset: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(appState.isLoadingChats ? Color(hex: "3370FF") : .secondary)
                        .rotationEffect(.degrees(appState.isLoadingChats ? 360 : 0))
                        .animation(appState.isLoadingChats ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoadingChats)
                }
                .buttonStyle(.plain)
                .help("刷新群组列表 (Cmd+R)")
            }
            
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("搜索群名称或 Chat ID...", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !appState.searchQuery.isEmpty {
                    Button {
                        appState.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Filter Pills
            HStack(spacing: 6) {
                ForEach(ChatFilterMode.allCases) { mode in
                    filterPill(mode: mode)
                }
                Spacer()
            }
        }
    }
    
    private func filterPill(mode: ChatFilterMode) -> some View {
        let isSelected = appState.filterMode == mode
        return Button {
            appState.filterMode = mode
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(hex: "3370FF") : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color(hex: "3370FF").opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var chatListContent: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(appState.filteredChats) { chat in
                    ChatRowView(
                        chat: chat,
                        isSelected: appState.selectedChat?.id == chat.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectedChat = chat
                    }
                }
                
                if appState.hasMoreChats {
                    Button {
                        Task {
                            await appState.loadMoreChats()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if appState.isLoadingChats {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appState.isLoadingChats ? "加载中..." : "加载更多群组")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("正在拉取群聊列表...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text("拉取群聊失败")
                .font(.system(size: 13, weight: .semibold))
            
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            Button("重试") {
                Task {
                    await appState.loadChats(reset: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text(appState.searchQuery.isEmpty ? "暂无群聊" : "未找到匹配群聊")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            if !appState.searchQuery.isEmpty {
                Button("清除搜索") {
                    appState.searchQuery = ""
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }
            
            Spacer()
        }
    }
}
