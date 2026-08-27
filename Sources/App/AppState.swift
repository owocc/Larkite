import Foundation
import SwiftUI
import AppKit

public enum NavigationTab: String, CaseIterable, Identifiable {
    case chats = "群组会话"
    case settings = "设置"
    case debug = "接口调试"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .settings: return "gearshape.fill"
        case .debug: return "curlybraces.square.fill"
        }
    }
}

public enum ChatFilterMode: String, CaseIterable, Identifiable {
    case all = "全部"
    case group = "群聊"
    case p2p = "私聊"
    case `internal` = "内部"
    case external = "外部"
    
    public var id: String { rawValue }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // MARK: - Published Properties
    
    @Published public var session: UserSession?
    @Published public var isAuthenticating: Bool = false
    @Published public var authError: String?
    @Published public var authStatusMessage: String = ""
    @Published public var isLocalServerRunning: Bool = false
    @Published public var localServerPort: UInt16 = 8989
    
    @Published public var selectedTab: NavigationTab = .chats
    
    @Published public var chats: [FeishuChatItem] = []
    @Published public var selectedChat: FeishuChatItem? {
        didSet {
            if let chat = selectedChat, oldValue?.id != chat.id {
                Task {
                    await loadMessages(for: chat, reset: true)
                }
            }
        }
    }
    @Published public var isLoadingChats: Bool = false
    @Published public var chatError: String?
    @Published public var searchQuery: String = ""
    @Published public var filterMode: ChatFilterMode = .all
    @Published public var pageToken: String?
    @Published public var hasMoreChats: Bool = false
    
    // MARK: - Messages State
    @Published public var messages: [FeishuMessageItem] = []
    @Published public var isLoadingMessages: Bool = false
    @Published public var messageError: String?
    @Published public var messagePageToken: String?
    @Published public var hasMoreMessages: Bool = false
    @Published public var selectedMessageForInspection: FeishuMessageItem?
    private var oauthServerTask: Task<Void, Never>?
    
    public var isLoggedIn: Bool {
        session != nil && !(session?.accessToken.isEmpty ?? true)
    }
    
    public var filteredChats: [FeishuChatItem] {
        var list = chats
        
        // Filter by mode
        switch filterMode {
        case .all:
            break
        case .group:
            list = list.filter { !$0.isP2P }
        case .p2p:
            list = list.filter { $0.isP2P }
        case .internal:
            list = list.filter { !$0.isExternal }
        case .external:
            list = list.filter { $0.isExternal }
        }
        
        // Filter by search query
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter { chat in
                chat.displayName.lowercased().contains(query) ||
                (chat.description?.lowercased().contains(query) ?? false) ||
                chat.chatId.lowercased().contains(query)
            }
        }
        
        return list
    }
    
    private init() {
        // Restore session if exists
        if let savedSession = ConfigManager.shared.loadSession() {
            self.session = savedSession
            Task {
                await self.loadUserInfo()
                await self.loadChats(reset: true)
            }
        }
    }
    
    // MARK: - OAuth Login Flow (On-Demand Local Server)
    
    public func startOAuthLogin() {
        let config = ConfigManager.shared.config
        localServerPort = config.port
        
        guard !config.appId.isEmpty, !config.appSecret.isEmpty else {
            authError = "请先输入 App ID 和 App Secret"
            return
        }
        
        guard let authUrl = FeishuAPIClient.shared.buildAuthorizeURL(
            appId: config.appId,
            redirectUri: config.redirectUri,
            scopes: config.scopes
        ) else {
            authError = "无法生成授权链接，请检查配置"
            return
        }
        
        isAuthenticating = true
        isLocalServerRunning = true
        authError = nil
        authStatusMessage = "已临时启动本地 127.0.0.1:\(config.port) 监听，正在打开授权页面..."
        
        // Open default browser
        NSWorkspace.shared.open(authUrl)
        
        oauthServerTask?.cancel()
        oauthServerTask = Task {
            do {
                // Starts server temporarily, waits for callback, auto stops
                let code = try await LocalCallbackServer.shared.startAndListen(port: config.port)
                await LocalCallbackServer.shared.stop()
                self.isLocalServerRunning = false
                
                await handleIncomingAuthCode(code)
            } catch {
                await LocalCallbackServer.shared.stop()
                self.isLocalServerRunning = false
                
                if !Task.isCancelled {
                    self.authError = error.localizedDescription
                    self.isAuthenticating = false
                    self.authStatusMessage = ""
                }
            }
        }
    }
    
    public func handleIncomingAuthCode(_ rawInput: String) async {
        // Clean up server if it was running
        await LocalCallbackServer.shared.stop()
        self.isLocalServerRunning = false
        
        let code = extractAuthCode(from: rawInput)
        guard !code.isEmpty else {
            authError = "未能从输入中提取到有效的 authorization code"
            isAuthenticating = false
            return
        }
        
        let config = ConfigManager.shared.config
        guard !config.appId.isEmpty, !config.appSecret.isEmpty else {
            authError = "请先配置 App ID 和 App Secret"
            isAuthenticating = false
            return
        }
        
        isAuthenticating = true
        authError = nil
        authStatusMessage = "获取授权码成功，正在换取 Access Token..."
        
        do {
            let tokenResp = try await FeishuAPIClient.shared.fetchUserAccessToken(
                appId: config.appId,
                appSecret: config.appSecret,
                code: code,
                redirectUri: config.redirectUri
            )
            
            guard let accessToken = tokenResp.accessToken else {
                throw FeishuAPIClient.APIError.invalidResponse
            }
            
            let expiresAt = tokenResp.expiresIn.map { Date().addingTimeInterval(Double($0)) }
            var newSession = UserSession(
                tokenType: .userAccessToken,
                accessToken: accessToken,
                refreshToken: tokenResp.refreshToken,
                expiresAt: expiresAt,
                user: nil
            )
            
            authStatusMessage = "正在获取个人资料..."
            if let userInfo = try? await FeishuAPIClient.shared.fetchUserInfo(token: accessToken) {
                newSession.user = userInfo
            }
            
            self.session = newSession
            ConfigManager.shared.saveSession(newSession)
            self.isAuthenticating = false
            self.authStatusMessage = ""
            
            await self.loadChats(reset: true)
        } catch {
            self.authError = error.localizedDescription
            self.isAuthenticating = false
            self.authStatusMessage = ""
        }
    }
    
    public func extractAuthCode(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                return code
            }
        }
        if trimmed.contains("code=") {
            let parts = trimmed.components(separatedBy: "code=")
            if let second = parts.last {
                return second.components(separatedBy: "&").first ?? second
            }
        }
        return trimmed
    }
    
    public func cancelOAuthLogin() {
        oauthServerTask?.cancel()
        Task {
            await LocalCallbackServer.shared.stop()
            self.isLocalServerRunning = false
            self.isAuthenticating = false
            self.authStatusMessage = ""
        }
    }
    
    // MARK: - Direct Token Login
    
    public func loginWithDirectToken(token: String, tokenType: UserSession.TokenType) async {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            authError = "Token 不能为空"
            return
        }
        
        isAuthenticating = true
        authError = nil
        authStatusMessage = "正在验证 Token 并拉取数据..."
        
        var newSession = UserSession(
            tokenType: tokenType,
            accessToken: cleanToken,
            refreshToken: nil,
            expiresAt: nil,
            user: nil
        )
        
        do {
            if tokenType == .userAccessToken || tokenType == .directToken {
                if let userInfo = try? await FeishuAPIClient.shared.fetchUserInfo(token: cleanToken) {
                    newSession.user = userInfo
                }
            }
            
            // Test fetch chat list
            _ = try await FeishuAPIClient.shared.fetchChatList(token: cleanToken, pageSize: 5)
            
            self.session = newSession
            ConfigManager.shared.saveSession(newSession)
            self.isAuthenticating = false
            self.authStatusMessage = ""
            
            await self.loadChats(reset: true)
        } catch {
            self.authError = "Token 验证失败: \(error.localizedDescription)"
            self.isAuthenticating = false
            self.authStatusMessage = ""
        }
    }
    
    // MARK: - App Credentials (Tenant Token) Login
    
    public func loginWithAppCredentials(appId: String, appSecret: String) async {
        guard !appId.isEmpty, !appSecret.isEmpty else {
            authError = "App ID 与 App Secret 不能为空"
            return
        }
        
        isAuthenticating = true
        authError = nil
        authStatusMessage = "正在请求 Tenant Access Token..."
        
        do {
            let token = try await FeishuAPIClient.shared.fetchTenantAccessToken(appId: appId, appSecret: appSecret)
            
            let newSession = UserSession(
                tokenType: .tenantAccessToken,
                accessToken: token,
                refreshToken: nil,
                expiresAt: Date().addingTimeInterval(7000),
                user: FeishuUserInfo(
                    name: "自建应用 (\(appId.prefix(8)))",
                    enName: nil,
                    avatarUrl: nil,
                    avatarThumb: nil,
                    avatarMiddle: nil,
                    avatarBig: nil,
                    openId: nil,
                    unionId: nil,
                    email: nil,
                    enterpriseEmail: nil,
                    userId: nil,
                    mobile: nil,
                    tenantKey: nil,
                    employeeNo: nil
                )
            )
            
            self.session = newSession
            ConfigManager.shared.saveSession(newSession)
            self.isAuthenticating = false
            self.authStatusMessage = ""
            
            await self.loadChats(reset: true)
        } catch {
            self.authError = "自建应用登录失败: \(error.localizedDescription)"
            self.isAuthenticating = false
            self.authStatusMessage = ""
        }
    }
    
    // MARK: - User Info & Session Refresh
    
    public func loadUserInfo() async {
        guard let token = session?.accessToken else { return }
        if let user = try? await FeishuAPIClient.shared.fetchUserInfo(token: token) {
            self.session?.user = user
            if let currentSession = self.session {
                ConfigManager.shared.saveSession(currentSession)
            }
        }
    }
    
    public func logout() {
        cancelOAuthLogin()
        self.session = nil
        self.chats = []
        self.selectedChat = nil
        ConfigManager.shared.clearSession()
    }
    
    // MARK: - Chat List Query
    
    public func loadChats(reset: Bool = false) async {
        guard let token = session?.accessToken else { return }
        
        if reset {
            isLoadingChats = true
            chatError = nil
            pageToken = nil
            chats = []
        }
        
        do {
            let result = try await FeishuAPIClient.shared.fetchChatList(
                token: token,
                pageToken: reset ? nil : pageToken,
                pageSize: 50
            )
            
            let newItems = result.items ?? []
            if reset {
                self.chats = newItems
            } else {
                self.chats.append(contentsOf: newItems)
            }
            
            self.pageToken = result.pageToken
            self.hasMoreChats = result.hasMore ?? false
            self.isLoadingChats = false
            
            if selectedChat == nil, let first = self.chats.first {
                self.selectedChat = first
                Task {
                    await self.loadMessages(for: first, reset: true)
                }
            }
        } catch {
            self.chatError = error.localizedDescription
            self.isLoadingChats = false
        }
    }
    
    public func loadMoreChats() async {
        guard !isLoadingChats, hasMoreChats, pageToken != nil else { return }
        await loadChats(reset: false)
    }
    
    // MARK: - Message History Query
    
    public func selectChat(_ chat: FeishuChatItem) {
        self.selectedChat = chat
    }
    
    public func loadMessages(for chat: FeishuChatItem, reset: Bool = false) async {
        guard let token = session?.accessToken else { return }
        
        if reset {
            isLoadingMessages = true
            messageError = nil
            messagePageToken = nil
            messages = []
        }
        
        do {
            let result = try await FeishuAPIClient.shared.fetchChatMessages(
                token: token,
                chatId: chat.chatId,
                sortType: "ByCreateTimeAsc",
                pageToken: reset ? nil : messagePageToken,
                pageSize: 40
            )
            
            let newItems = result.items ?? []
            if reset {
                self.messages = newItems
            } else {
                // Prepend older messages when scrolling up
                self.messages.insert(contentsOf: newItems, at: 0)
            }
            
            self.messagePageToken = result.pageToken
            self.hasMoreMessages = result.hasMore ?? false
            self.isLoadingMessages = false
        } catch {
            self.messageError = error.localizedDescription
            self.isLoadingMessages = false
        }
    }
    
    public func loadMoreMessages() async {
        guard let chat = selectedChat, !isLoadingMessages, hasMoreMessages, messagePageToken != nil else { return }
        await loadMessages(for: chat, reset: false)
    }
    
    // MARK: - Direct / Single Chat (p2p)
    
    public func openDirectChat(chatId: String) async throws {
        let cleanId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty, let token = session?.accessToken else { return }
        
        // Check if already in list
        if let existing = chats.first(where: { $0.chatId == cleanId }) {
            self.selectedChat = existing
            return
        }
        
        // Fetch chat metadata from OpenAPI
        let chatItem = try await FeishuAPIClient.shared.fetchChatInfo(token: token, chatId: cleanId)
        self.chats.insert(chatItem, at: 0)
        self.selectedChat = chatItem
    }
}
