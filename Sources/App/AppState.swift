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
    @Published public var isAddingAccount: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var authError: String?
    @Published public var authStatusMessage: String = ""
    @Published public var isLocalServerRunning: Bool = false
    @Published public var localServerPort: UInt16 = 8989
    
    @Published public var selectedTab: NavigationTab = .chats
    @Published public var isShowingSettings: Bool = false
    @Published public var isShowingDebug: Bool = false
    
    @Published public var chats: [FeishuChatItem] = []
    @Published public var selectedChat: FeishuChatItem? {
        didSet {
            guard let chat = selectedChat else { return }
            if oldValue?.chatId != chat.chatId {
                activeMessageLoadTask?.cancel()
                activeMessageLoadTask = Task {
                    await loadMessages(for: chat, reset: true)
                }
                
                activeMembersLoadTask?.cancel()
                self.chatMembers = []
                self.chatMemberTotal = 0
                self.chatMemberError = nil
                self.chatMemberPageToken = nil
                self.hasMoreChatMembers = false
            }
        }
    }
    @Published public var isLoadingChats: Bool = false
    @Published public var chatError: String?
    @Published public var searchQuery: String = ""
    @Published public var filterMode: ChatFilterMode = .all
    @Published public var pageToken: String?
    @Published public var hasMoreChats: Bool = false
    
    // MARK: - Contacts & Private Messages State
    @Published public var contacts: [FeishuContactUser] = []
    @Published public var isScanningP2PChats: Bool = false
    @Published public var isLoadingContacts: Bool = false
    
    // MARK: - Messages State
    @Published public var messages: [FeishuMessageItem] = []
    @Published public var isLoadingMessages: Bool = false
    @Published public var messageError: String?
    @Published public var messagePageToken: String?
    @Published public var hasMoreMessages: Bool = false
    @Published public var selectedMessageForInspection: FeishuMessageItem?
    @Published public var isSendingMessage: Bool = false
    @Published public var replyingToMessage: FeishuMessageItem? = nil
    @Published public var lastMessages: [String: FeishuMessageItem] = [:]
    
    // MARK: - Group Members State
    @Published public var chatMembers: [FeishuChatMemberItem] = []
    @Published public var isLoadingChatMembers: Bool = false
    @Published public var chatMemberError: String? = nil
    @Published public var chatMemberTotal: Int = 0
    @Published public var chatMemberPageToken: String? = nil
    @Published public var hasMoreChatMembers: Bool = false
    
    // MARK: - User Profile Inspection State
    @Published public var inspectedUser: DetailedFeishuUser? = nil
    @Published public var isInspectingUser: Bool = false
    
    private var oauthServerTask: Task<Void, Never>?
    private var activeMessageLoadTask: Task<Void, Never>?
    private var activeMembersLoadTask: Task<Void, Never>?
    
    public var isLoggedIn: Bool {
        !isAddingAccount && session != nil && !(session?.accessToken.isEmpty ?? true)
    }
    
    public var filteredChats: [FeishuChatItem] {
        var list = chats
        
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
        let activeId = ConfigManager.shared.activeAccountId
        self.chats = ConfigManager.shared.loadP2PChats(forAccountId: activeId)
        
        if let savedSession = ConfigManager.shared.loadSession(forAccountId: activeId) {
            self.session = savedSession
            Task {
                await self.loadUserInfo()
                await self.loadChats(reset: true)
            }
        }
    }
    
    // MARK: - OAuth Login Flow (On-Demand Local Server)
    
    public func startOAuthLogin(customConfig: AppConfig? = nil) {
        let config = customConfig ?? ConfigManager.shared.config
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
        
        NSWorkspace.shared.open(authUrl)
        
        oauthServerTask?.cancel()
        oauthServerTask = Task {
            do {
                let code = try await LocalCallbackServer.shared.startAndListen(port: config.port)
                await LocalCallbackServer.shared.stop()
                self.isLocalServerRunning = false
                
                await handleIncomingAuthCode(code, customConfig: config)
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
    
    public func handleIncomingAuthCode(_ rawInput: String, customConfig: AppConfig? = nil) async {
        await LocalCallbackServer.shared.stop()
        self.isLocalServerRunning = false
        
        let code = extractAuthCode(from: rawInput)
        guard !code.isEmpty else {
            authError = "未能从输入中提取到有效的 authorization code"
            isAuthenticating = false
            return
        }
        
        let config = customConfig ?? ConfigManager.shared.config
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
            _ = ConfigManager.shared.saveAccountSession(
                user: newSession.user,
                session: newSession,
                config: config
            )
            self.isAuthenticating = false
            self.isAddingAccount = false
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
            
            _ = try await FeishuAPIClient.shared.fetchChatList(token: cleanToken, pageSize: 5)
            
            self.session = newSession
            _ = ConfigManager.shared.saveAccountSession(
                user: newSession.user,
                session: newSession,
                config: ConfigManager.shared.config
            )
            self.isAuthenticating = false
            self.isAddingAccount = false
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
            _ = ConfigManager.shared.saveAccountSession(
                user: newSession.user,
                session: newSession,
                config: ConfigManager.shared.config
            )
            self.isAuthenticating = false
            self.isAddingAccount = false
            self.authStatusMessage = ""
            
            await self.loadChats(reset: true)
        } catch {
            self.authError = "自建应用登录失败: \(error.localizedDescription)"
            self.isAuthenticating = false
            self.authStatusMessage = ""
        }
    }
    
    // MARK: - User Info & Multi-Account Operations
    
    public func loadUserInfo() async {
        guard let token = session?.accessToken else { return }
        if let user = try? await FeishuAPIClient.shared.fetchUserInfo(token: token) {
            self.session?.user = user
            UserProfileManager.shared.seedWith(user: user, contacts: self.contacts)
            if let currentSession = self.session {
                ConfigManager.shared.saveSession(currentSession)
            }
        }
    }
    
    public func startAddingNewAccount() {
        cancelOAuthLogin()
        self.isAddingAccount = true
    }
    
    public func cancelAddingAccount() {
        self.isAddingAccount = false
        if self.session == nil, let activeId = ConfigManager.shared.activeAccountId {
            self.switchAccount(to: activeId)
        }
    }
    
    public func switchAccount(to accountId: String) {
        guard let account = ConfigManager.shared.switchAccount(to: accountId) else { return }
        self.isAddingAccount = false
        self.session = account.session
        self.selectedChat = nil
        self.messages = []
        self.chatMembers = []
        self.chats = ConfigManager.shared.loadP2PChats(forAccountId: accountId)
        
        Task {
            await self.loadUserInfo()
            await self.loadChats(reset: true)
        }
    }
    
    public func removeAccount(id: String) {
        ConfigManager.shared.removeAccount(id: id)
        if let activeId = ConfigManager.shared.activeAccountId {
            switchAccount(to: activeId)
        } else {
            logoutAllAccounts()
        }
    }
    
    public func logoutCurrentAccount() {
        if let activeId = ConfigManager.shared.activeAccountId {
            removeAccount(id: activeId)
        } else {
            logoutAllAccounts()
        }
    }
    
    public func logoutAllAccounts() {
        cancelOAuthLogin()
        self.session = nil
        self.chats = []
        self.selectedChat = nil
        self.messages = []
        self.chatMembers = []
        self.isAddingAccount = false
        ConfigManager.shared.clearAllAccounts()
    }
    
    public func logout() {
        logoutCurrentAccount()
    }
    
    // MARK: - Chat List Query
    
    public func loadChats(reset: Bool = false) async {
        guard let token = session?.accessToken else { return }
        
        if reset {
            isLoadingChats = true
            chatError = nil
            let savedP2P = ConfigManager.shared.loadP2PChats()
            self.chats = savedP2P
            Task {
                await self.loadContacts()
            }
        }
        
        do {
            let result = try await FeishuAPIClient.shared.fetchChatList(
                token: token,
                pageToken: reset ? nil : pageToken,
                pageSize: 50
            )
            
            let newItems = result.items ?? []
            if reset {
                let savedP2P = ConfigManager.shared.loadP2PChats()
                self.chats = newItems + savedP2P.filter { saved in
                    !newItems.contains(where: { $0.chatId == saved.chatId })
                }
            } else {
                self.chats.append(contentsOf: newItems)
            }
            
            self.pageToken = result.pageToken
            self.hasMoreChats = result.hasMore ?? false
            self.isLoadingChats = false
            
            if selectedChat == nil, let first = self.chats.first {
                self.selectedChat = first
            }
            
            Task {
                let hydratedItems = await FeishuAPIClient.shared.hydrateChatsWithDetails(
                    token: token,
                    items: newItems
                )
                
                if reset {
                    let p2pSaved = ConfigManager.shared.loadP2PChats()
                    self.chats = hydratedItems + p2pSaved.filter { saved in
                        !hydratedItems.contains(where: { $0.chatId == saved.chatId })
                    }
                } else {
                    var current = self.chats
                    let startIndex = max(0, current.count - hydratedItems.count)
                    for (i, hydrated) in hydratedItems.enumerated() {
                        let targetIdx = startIndex + i
                        if targetIdx < current.count {
                            current[targetIdx] = hydrated
                        }
                    }
                    self.chats = current
                }
                
                ConfigManager.shared.saveP2PChats(self.chats)
                
                if let selected = self.selectedChat,
                   let updated = self.chats.first(where: { $0.chatId == selected.chatId }),
                   selected != updated {
                    self.selectedChat = updated
                }
                
                let latestMap = await FeishuAPIClient.shared.batchFetchLatestMessages(
                    token: token,
                    chatIds: self.chats.map(\.chatId)
                )
                for (cid, msg) in latestMap {
                    self.lastMessages[cid] = msg
                    if let mentions = msg.mentions {
                        UserProfileManager.shared.seedWithMentions(mentions)
                    }
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
    
    public func deepScanAllChatsAndP2P() async {
        guard let token = session?.accessToken else { return }
        isScanningP2PChats = true
        
        let allHydrated = await FeishuAPIClient.shared.scanAndHydrateAllChats(token: token)
        if !allHydrated.isEmpty {
            let p2pOnly = allHydrated.filter { $0.isP2P }
            ConfigManager.shared.saveP2PChats(p2pOnly)
            self.chats = allHydrated
            
            if let selected = self.selectedChat,
               let updated = self.chats.first(where: { $0.chatId == selected.chatId }) {
                self.selectedChat = updated
            }
        }
        
        isScanningP2PChats = false
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
        
        var targetChatId = chat.chatId
        
        if !targetChatId.hasPrefix("oc_") {
            if let matched = self.chats.first(where: { $0.isP2P && $0.chatId.hasPrefix("oc_") && ($0.ownerId == chat.chatId || $0.ownerId == chat.ownerId) }) {
                targetChatId = matched.chatId
            } else {
                self.messages = []
                self.isLoadingMessages = false
                return
            }
        }
        
        do {
            let result = try await FeishuAPIClient.shared.fetchChatMessages(
                token: token,
                chatId: targetChatId,
                sortType: "ByCreateTimeDesc",
                pageToken: reset ? nil : messagePageToken,
                pageSize: 40
            )
            
            let rawItems = result.items ?? []
            for item in rawItems {
                if let mentions = item.mentions {
                    UserProfileManager.shared.seedWithMentions(mentions)
                }
            }
            
            let sortedBatch = rawItems.sorted(by: { $0.createdDate < $1.createdDate })
            
            if reset {
                self.messages = sortedBatch
            } else {
                self.messages.insert(contentsOf: sortedBatch, at: 0)
            }
            
            self.messagePageToken = result.pageToken
            self.hasMoreMessages = result.hasMore ?? false
            self.isLoadingMessages = false
            
            if let latest = sortedBatch.last {
                self.lastMessages[targetChatId] = latest
                self.lastMessages[chat.chatId] = latest
            }
            
            if chat.isP2P {
                let currentUserId = self.session?.user?.openId
                if let peerMsg = rawItems.first(where: { $0.sender?.id != currentUserId && $0.sender?.id != nil }) {
                    if let senderId = peerMsg.sender?.id {
                        let peerName = UserProfileManager.shared.resolveDisplayName(for: senderId, currentUserId: currentUserId)
                        if !peerName.hasPrefix("用户 (") {
                            if let idx = self.chats.firstIndex(where: { $0.chatId == chat.chatId }) {
                                let updated = FeishuChatItem(
                                    chatId: chat.chatId,
                                    avatar: chat.avatar,
                                    name: peerName,
                                    description: "单聊 · \(peerName)",
                                    ownerId: senderId,
                                    ownerIdType: "open_id",
                                    external: chat.external,
                                    tenantKey: chat.tenantKey,
                                    chatStatus: chat.chatStatus,
                                    chatMode: "p2p",
                                    chatType: "private",
                                    chatTag: chat.chatTag,
                                    userCount: "2",
                                    botCount: chat.botCount
                                )
                                self.chats[idx] = updated
                                if self.selectedChat?.chatId == chat.chatId {
                                    self.selectedChat = updated
                                }
                                ConfigManager.shared.saveP2PChats(self.chats)
                            }
                        }
                    }
                }
            }
        } catch {
            self.messageError = error.localizedDescription
            self.isLoadingMessages = false
        }
    }
    
    public func loadMoreMessages() async {
        guard let chat = selectedChat, !isLoadingMessages, hasMoreMessages, messagePageToken != nil else { return }
        await loadMessages(for: chat, reset: false)
    }
    
    // MARK: - Send / Reply / Recall / Reactions
    
    public func sendTextMessage(_ text: String) async throws {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty, let chat = selectedChat, let token = session?.accessToken else { return }
        
        isSendingMessage = true
        defer { isSendingMessage = false }
        
        if let replyTarget = replyingToMessage {
            let sentMsg = try await FeishuAPIClient.shared.replyMessage(
                token: token,
                messageId: replyTarget.messageId,
                text: cleanText
            )
            self.messages.append(sentMsg)
            self.replyingToMessage = nil
        } else {
            let receiveIdType = chat.isP2P && !chat.chatId.hasPrefix("oc_") ? "open_id" : "chat_id"
            let sentMsg = try await FeishuAPIClient.shared.sendMessage(
                token: token,
                receiveIdType: receiveIdType,
                receiveId: chat.chatId,
                text: cleanText
            )
            self.messages.append(sentMsg)
            self.lastMessages[chat.chatId] = sentMsg
            if let realChatId = sentMsg.chatId {
                self.lastMessages[realChatId] = sentMsg
            }
            
            if let newChatId = sentMsg.chatId, newChatId.hasPrefix("oc_") && chat.chatId != newChatId {
                let updatedChat = FeishuChatItem(
                    chatId: newChatId,
                    avatar: chat.avatar,
                    name: chat.name,
                    description: chat.description,
                    ownerId: chat.ownerId ?? chat.chatId,
                    ownerIdType: chat.ownerIdType ?? "open_id",
                    external: chat.external,
                    tenantKey: chat.tenantKey,
                    chatStatus: chat.chatStatus,
                    chatMode: "p2p",
                    chatType: "private",
                    chatTag: "p2p",
                    userCount: "2",
                    botCount: "0"
                )
                if let idx = self.chats.firstIndex(where: { $0.chatId == chat.chatId }) {
                    self.chats[idx] = updatedChat
                } else {
                    self.chats.insert(updatedChat, at: 0)
                }
                self.selectedChat = updatedChat
                ConfigManager.shared.saveP2PChats(self.chats)
            }
        }
    }
    
    public func sendImage(imageData: Data, fileName: String = "image.png") async throws {
        guard !imageData.isEmpty, let chat = selectedChat, let token = session?.accessToken else { return }
        
        isSendingMessage = true
        defer { isSendingMessage = false }
        
        let lowerName = fileName.lowercased()
        let mimeType: String
        if lowerName.hasSuffix(".jpg") || lowerName.hasSuffix(".jpeg") {
            mimeType = "image/jpeg"
        } else if lowerName.hasSuffix(".webp") {
            mimeType = "image/webp"
        } else if lowerName.hasSuffix(".gif") {
            mimeType = "image/gif"
        } else {
            mimeType = "image/png"
        }
        
        let imageKey = try await FeishuAPIClient.shared.uploadImage(
            token: token,
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )
        
        if let replyTarget = replyingToMessage {
            let sentMsg = try await FeishuAPIClient.shared.replyImageMessage(
                token: token,
                messageId: replyTarget.messageId,
                imageKey: imageKey
            )
            self.messages.append(sentMsg)
            self.replyingToMessage = nil
        } else {
            let receiveIdType = chat.isP2P && !chat.chatId.hasPrefix("oc_") ? "open_id" : "chat_id"
            let sentMsg = try await FeishuAPIClient.shared.sendImageMessage(
                token: token,
                receiveIdType: receiveIdType,
                receiveId: chat.chatId,
                imageKey: imageKey
            )
            self.messages.append(sentMsg)
            self.lastMessages[chat.chatId] = sentMsg
            if let realChatId = sentMsg.chatId {
                self.lastMessages[realChatId] = sentMsg
            }
            
            if let newChatId = sentMsg.chatId, newChatId.hasPrefix("oc_") && chat.chatId != newChatId {
                let updatedChat = FeishuChatItem(
                    chatId: newChatId,
                    avatar: chat.avatar,
                    name: chat.name,
                    description: chat.description,
                    ownerId: chat.ownerId ?? chat.chatId,
                    ownerIdType: chat.ownerIdType ?? "open_id",
                    external: chat.external,
                    tenantKey: chat.tenantKey,
                    chatStatus: chat.chatStatus,
                    chatMode: "p2p",
                    chatType: "private",
                    chatTag: "p2p",
                    userCount: "2",
                    botCount: "0"
                )
                if let idx = self.chats.firstIndex(where: { $0.chatId == chat.chatId }) {
                    self.chats[idx] = updatedChat
                } else {
                    self.chats.insert(updatedChat, at: 0)
                }
                self.selectedChat = updatedChat
                ConfigManager.shared.saveP2PChats(self.chats)
            }
        }
    }
    
    public func sendFile(fileData: Data, fileName: String) async throws {
        guard !fileData.isEmpty, let chat = selectedChat, let token = session?.accessToken else { return }
        
        isSendingMessage = true
        defer { isSendingMessage = false }
        
        let ext = (fileName as NSString).pathExtension.lowercased()
        let fileType: String
        switch ext {
        case "mp4", "mov": fileType = "mp4"
        case "pdf": fileType = "pdf"
        case "doc", "docx": fileType = "doc"
        case "xls", "xlsx": fileType = "xls"
        case "ppt", "pptx": fileType = "ppt"
        case "opus": fileType = "opus"
        default: fileType = "stream"
        }
        
        let fileKey = try await FeishuAPIClient.shared.uploadFile(
            token: token,
            fileData: fileData,
            fileName: fileName,
            fileType: fileType
        )
        
        if let replyTarget = replyingToMessage {
            let sentMsg = try await FeishuAPIClient.shared.replyFileMessage(
                token: token,
                messageId: replyTarget.messageId,
                fileKey: fileKey
            )
            self.messages.append(sentMsg)
            self.replyingToMessage = nil
        } else {
            let receiveIdType = chat.isP2P && !chat.chatId.hasPrefix("oc_") ? "open_id" : "chat_id"
            let sentMsg = try await FeishuAPIClient.shared.sendFileMessage(
                token: token,
                receiveIdType: receiveIdType,
                receiveId: chat.chatId,
                fileKey: fileKey
            )
            self.messages.append(sentMsg)
            self.lastMessages[chat.chatId] = sentMsg
            if let realChatId = sentMsg.chatId {
                self.lastMessages[realChatId] = sentMsg
            }
            
            if let newChatId = sentMsg.chatId, newChatId.hasPrefix("oc_") && chat.chatId != newChatId {
                let updatedChat = FeishuChatItem(
                    chatId: newChatId,
                    avatar: chat.avatar,
                    name: chat.name,
                    description: chat.description,
                    ownerId: chat.ownerId ?? chat.chatId,
                    ownerIdType: chat.ownerIdType ?? "open_id",
                    external: chat.external,
                    tenantKey: chat.tenantKey,
                    chatStatus: chat.chatStatus,
                    chatMode: "p2p",
                    chatType: "private",
                    chatTag: "p2p",
                    userCount: "2",
                    botCount: "0"
                )
                if let idx = self.chats.firstIndex(where: { $0.chatId == chat.chatId }) {
                    self.chats[idx] = updatedChat
                } else {
                    self.chats.insert(updatedChat, at: 0)
                }
                self.selectedChat = updatedChat
                ConfigManager.shared.saveP2PChats(self.chats)
            }
        }
    }
    
    public func sendClipboardImage() async throws -> Bool {
        let pasteboard = NSPasteboard.general
        
        if let pngData = pasteboard.data(forType: .png) {
            let timestamp = Int(Date().timeIntervalSince1970)
            try await sendImage(imageData: pngData, fileName: "截屏_\(timestamp).png")
            return true
        }
        
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData),
           let tiffRep = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRep),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let timestamp = Int(Date().timeIntervalSince1970)
            try await sendImage(imageData: pngData, fileName: "截屏_\(timestamp).png")
            return true
        }
        
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstUrl = urls.first {
            let ext = firstUrl.pathExtension.lowercased()
            guard let fileData = try? Data(contentsOf: firstUrl) else { return false }
            
            if ["png", "jpg", "jpeg", "webp", "gif", "bmp", "heic", "tiff"].contains(ext) {
                try await sendImage(imageData: fileData, fileName: firstUrl.lastPathComponent)
                return true
            } else {
                try await sendFile(fileData: fileData, fileName: firstUrl.lastPathComponent)
                return true
            }
        }
        
        return false
    }
    
    public func recallMessageItem(_ message: FeishuMessageItem) async throws {
        guard let token = session?.accessToken else { return }
        try await FeishuAPIClient.shared.recallMessage(token: token, messageId: message.messageId)
        
        if let index = self.messages.firstIndex(where: { $0.messageId == message.messageId }) {
            let original = self.messages[index]
            let updated = FeishuMessageItem(
                messageId: original.messageId,
                rootId: original.rootId,
                parentId: original.parentId,
                threadId: original.threadId,
                msgType: original.msgType,
                createTime: original.createTime,
                updateTime: original.updateTime,
                deleted: true,
                updated: original.updated,
                chatId: original.chatId,
                sender: original.sender,
                body: original.body,
                mentions: original.mentions,
                upperMessageId: original.upperMessageId
            )
            self.messages[index] = updated
        }
    }
    
    public func addReaction(to message: FeishuMessageItem, emojiType: String) async throws {
        guard let token = session?.accessToken else { return }
        try await FeishuAPIClient.shared.addMessageReaction(
            token: token,
            messageId: message.messageId,
            emojiType: emojiType
        )
    }
    
    // MARK: - Group Members Query
    
    public func loadChatMembers(for chat: FeishuChatItem, reset: Bool = false) async {
        guard let token = session?.accessToken else { return }
        
        if reset {
            isLoadingChatMembers = true
            chatMemberError = nil
            chatMemberPageToken = nil
            chatMembers = []
            chatMemberTotal = 0
        }
        
        do {
            let result = try await FeishuAPIClient.shared.fetchChatMembers(
                token: token,
                chatId: chat.chatId,
                pageToken: reset ? nil : chatMemberPageToken,
                pageSize: 100
            )
            
            let newItems = result.items ?? []
            UserProfileManager.shared.seedWithMembers(newItems)
            
            if reset {
                self.chatMembers = newItems
            } else {
                self.chatMembers.append(contentsOf: newItems)
            }
            
            self.chatMemberPageToken = result.pageToken
            self.hasMoreChatMembers = result.hasMore ?? false
            if let total = result.memberTotal {
                self.chatMemberTotal = total
            } else {
                self.chatMemberTotal = self.chatMembers.count
            }
            self.isLoadingChatMembers = false
        } catch {
            self.chatMemberError = error.localizedDescription
            self.isLoadingChatMembers = false
        }
    }
    
    public func loadMoreChatMembers() async {
        guard let chat = selectedChat, !isLoadingChatMembers, hasMoreChatMembers, chatMemberPageToken != nil else { return }
        await loadChatMembers(for: chat, reset: false)
    }
    
    // MARK: - Direct / Single Chat (p2p)
    
    public func openDirectChat(chatId: String) async throws {
        let cleanId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty, let token = session?.accessToken else { return }
        
        if let existing = chats.first(where: { $0.chatId == cleanId }) {
            self.selectedChat = existing
            return
        }
        
        let chatItem = try await FeishuAPIClient.shared.fetchChatInfo(token: token, chatId: cleanId)
        self.chats.insert(chatItem, at: 0)
        self.selectedChat = chatItem
        ConfigManager.shared.saveP2PChats(self.chats)
    }
    
    public func openDirectChatWithUser(idType: String, idValue: String) async throws {
        let cleanId = idValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty, let token = session?.accessToken else { return }
        
        if idType == "message_id" || cleanId.hasPrefix("om_") {
            let msg = try await FeishuAPIClient.shared.fetchSingleMessage(token: token, messageId: cleanId)
            if let targetChatId = msg.chatId, !targetChatId.isEmpty {
                try await openDirectChat(chatId: targetChatId)
                return
            } else {
                throw FeishuAPIClient.APIError.feishuError(code: 404, msg: "未能在消息中找到所属 Chat ID")
            }
        }
        
        if idType == "chat_id" || cleanId.hasPrefix("oc_") {
            try await openDirectChat(chatId: cleanId)
            return
        }
        
        var actualType = idType
        if cleanId.hasPrefix("ou_") {
            actualType = "open_id"
        } else if cleanId.hasPrefix("on_") {
            actualType = "union_id"
        } else if cleanId.contains("@") {
            actualType = "email"
        }
        
        if let existing = self.chats.first(where: { $0.isP2P && ($0.ownerId == cleanId || $0.chatId == cleanId) }) {
            self.selectedChat = existing
            return
        }
        
        let p2pChat = try await FeishuAPIClient.shared.createOrGetP2PChat(
            token: token,
            receiveIdType: actualType,
            receiveId: cleanId
        )
        
        if let index = self.chats.firstIndex(where: { $0.chatId == p2pChat.chatId }) {
            self.selectedChat = self.chats[index]
        } else {
            self.chats.insert(p2pChat, at: 0)
            self.selectedChat = p2pChat
        }
        
        ConfigManager.shared.saveP2PChats(self.chats)
    }
    
    // MARK: - Enterprise Contacts Query
    
    public func loadContacts() async {
        guard let token = session?.accessToken else { return }
        isLoadingContacts = true
        
        do {
            let result = try await FeishuAPIClient.shared.fetchContacts(token: token, pageSize: 50)
            let fetchedContacts = result.items ?? []
            self.contacts = fetchedContacts
            UserProfileManager.shared.seedWith(user: self.session?.user, contacts: fetchedContacts)
            
            for contact in fetchedContacts {
                let p2pItem = contact.toP2PChatItem()
                let exists = self.chats.contains { chat in
                    chat.chatId == p2pItem.chatId || (chat.ownerId != nil && chat.ownerId == p2pItem.ownerId)
                }
                if !exists {
                    self.chats.append(p2pItem)
                }
            }
            
            ConfigManager.shared.saveP2PChats(self.chats)
            self.isLoadingContacts = false
        } catch {
            self.isLoadingContacts = false
        }
    }
    
    public func openContactChat(_ contact: FeishuContactUser) {
        let p2pItem = contact.toP2PChatItem()
        if let index = self.chats.firstIndex(where: { $0.chatId == p2pItem.chatId }) {
            self.selectedChat = self.chats[index]
        } else {
            self.chats.insert(p2pItem, at: 0)
            self.selectedChat = p2pItem
        }
        ConfigManager.shared.saveP2PChats(self.chats)
    }
    
    // MARK: - User Detail Profile Inspection
    
    public func inspectUser(openId: String, fallbackName: String? = nil, fallbackAvatar: String? = nil) async {
        guard !openId.isEmpty else { return }
        let token = session?.accessToken ?? ""
        
        isInspectingUser = true
        
        if !token.isEmpty {
            if let detail = try? await FeishuAPIClient.shared.fetchUserDetail(token: token, userId: openId) {
                self.inspectedUser = detail
                UserProfileManager.shared.registerUser(
                    openId: openId,
                    name: detail.displayName,
                    avatarUrl: detail.bestAvatarUrl,
                    email: detail.email ?? detail.enterpriseEmail,
                    jobTitle: detail.jobTitle
                )
                self.isInspectingUser = false
                return
            }
        }
        
        let cached = UserProfileManager.shared.getProfile(for: openId)
        let current = self.session?.user
        let isSelf = (openId == current?.openId || openId == current?.userId)
        
        let name = isSelf ? (current?.displayName ?? fallbackName ?? "我") : (cached?.name ?? fallbackName ?? "飞书用户")
        let avatarUrl = isSelf ? current?.bestAvatarUrl : (cached?.avatarUrl ?? fallbackAvatar)
        let email = isSelf ? (current?.email ?? current?.enterpriseEmail) : cached?.email
        let jobTitle = cached?.jobTitle
        
        let fallbackUser = DetailedFeishuUser(
            openId: openId,
            userId: isSelf ? current?.userId : nil,
            unionId: isSelf ? current?.unionId : nil,
            name: name,
            enName: isSelf ? current?.enName : nil,
            nickname: nil,
            email: email,
            enterpriseEmail: isSelf ? current?.enterpriseEmail : nil,
            mobile: isSelf ? current?.mobile : nil,
            mobileVisible: isSelf,
            gender: nil,
            avatar: FeishuContactAvatar(avatar72: avatarUrl, avatar240: avatarUrl, avatar640: avatarUrl, avatarOrigin: avatarUrl),
            status: DetailedUserStatus(isFrozen: false, isResigned: false, isActivated: true, isExited: false, isUnjoin: false),
            departmentIds: nil,
            leaderUserId: nil,
            city: nil,
            country: nil,
            workStation: nil,
            joinTime: nil,
            isTenantManager: nil,
            employeeNo: isSelf ? current?.employeeNo : nil,
            employeeType: nil,
            jobTitle: jobTitle,
            geo: nil,
            jobLevelId: nil,
            jobFamilyId: nil,
            departmentPath: nil,
            rawJsonString: nil
        )
        
        self.inspectedUser = fallbackUser
        self.isInspectingUser = false
    }
}
