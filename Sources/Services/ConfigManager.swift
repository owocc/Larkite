import Foundation

@MainActor
public final class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()
    
    private let userDefaultsKey = "LarkNative_AppConfig"
    private let sessionKey = "LarkNative_UserSession"
    private let accountsKey = "LarkNative_Accounts"
    private let activeAccountIdKey = "LarkNative_ActiveAccountId"
    private let p2pChatsPrefix = "LarkNative_P2PChats_"
    private let appSecretKeychainKey = "LarkNative_AppSecret"
    
    @Published public var config: AppConfig {
        didSet {
            saveConfig()
        }
    }
    
    @Published public var accounts: [AccountSession] = []
    @Published public var activeAccountId: String? = nil
    
    private init() {
        // 1. Load active account ID
        let savedActiveId = UserDefaults.standard.string(forKey: activeAccountIdKey)
        self.activeAccountId = savedActiveId
        
        // 2. Load accounts list
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let list = try? JSONDecoder().decode([AccountSession].self, from: data) {
            self.accounts = list
        } else {
            self.accounts = []
        }
        
        // 3. Load active config
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(AppConfig.self, from: data) {
            var loaded = saved
            if let secret = KeychainHelper.readString(key: appSecretKeychainKey) {
                loaded.appSecret = secret
            }
            
            var currentScopes = Set(loaded.scopes.components(separatedBy: " ").filter { !$0.isEmpty })
            currentScopes.remove("im:message.history:readonly")
            
            let essential = FeishuScopes.recommendedList.filter { $0.isEssential }.map(\.key)
            for key in essential {
                currentScopes.insert(key)
            }
            loaded.scopes = currentScopes.sorted().joined(separator: " ")
            self.config = loaded
        } else {
            self.config = .default
        }
    }
    
    // MARK: - Multi-Account Management
    
    public func saveAccountSession(
        user: FeishuUserInfo?,
        session: UserSession,
        config: AppConfig
    ) -> AccountSession {
        let accountId: String = {
            if let uid = user?.openId, !uid.isEmpty { return uid }
            if let uid = user?.userId, !uid.isEmpty { return uid }
            if let tid = user?.tenantKey, !tid.isEmpty { return tid }
            return !config.appId.isEmpty ? config.appId : UUID().uuidString
        }()
        
        let accountName = user?.displayName ?? "飞书用户"
        
        var account = AccountSession(
            id: accountId,
            name: accountName,
            enName: user?.enName,
            avatarUrl: user?.bestAvatarUrl,
            email: user?.email ?? user?.enterpriseEmail,
            mobile: user?.mobile,
            tenantKey: user?.tenantKey,
            tokenType: session.tokenType,
            session: session,
            config: config,
            lastActiveAt: Date()
        )
        
        // Update existing or append new
        if let idx = accounts.firstIndex(where: { $0.id == accountId }) {
            account.createdAt = accounts[idx].createdAt
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        
        self.activeAccountId = accountId
        self.config = config
        
        persistAccounts()
        saveSession(session, forAccountId: accountId)
        
        return account
    }
    
    public func switchAccount(to accountId: String) -> AccountSession? {
        guard let account = accounts.first(where: { $0.id == accountId }) else { return nil }
        self.activeAccountId = accountId
        self.config = account.config
        
        // Update lastActiveAt
        if let idx = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[idx].lastActiveAt = Date()
        }
        
        persistAccounts()
        return account
    }
    
    public func removeAccount(id: String) {
        accounts.removeAll(where: { $0.id == id })
        _ = KeychainHelper.delete(key: "\(sessionKey)_\(id)")
        UserDefaults.standard.removeObject(forKey: "\(p2pChatsPrefix)\(id)")
        
        if activeAccountId == id {
            if let next = accounts.first {
                _ = switchAccount(to: next.id)
            } else {
                activeAccountId = nil
                clearSession()
            }
        }
        
        persistAccounts()
    }
    
    public func clearAllAccounts() {
        for acc in accounts {
            _ = KeychainHelper.delete(key: "\(sessionKey)_\(acc.id)")
            UserDefaults.standard.removeObject(forKey: "\(p2pChatsPrefix)\(acc.id)")
        }
        accounts = []
        activeAccountId = nil
        UserDefaults.standard.removeObject(forKey: accountsKey)
        UserDefaults.standard.removeObject(forKey: activeAccountIdKey)
        clearSession()
    }
    
    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
        UserDefaults.standard.set(activeAccountId, forKey: activeAccountIdKey)
    }
    
    // MARK: - Scopes Configuration
    
    public func resetToMinimalIMScopes() {
        self.config.scopes = FeishuScopes.minimalIMString
        saveConfig()
    }
    
    public func resetToRecommendedScopes() {
        self.config.scopes = FeishuScopes.recommendedString
        saveConfig()
    }
    
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        if !config.appSecret.isEmpty {
            _ = KeychainHelper.saveString(key: appSecretKeychainKey, value: config.appSecret)
        }
        
        // Sync to active account if present
        if let activeId = activeAccountId, let idx = accounts.firstIndex(where: { $0.id == activeId }) {
            accounts[idx].config = config
            persistAccounts()
        }
    }
    
    // MARK: - Isolated Session Storage
    
    public func saveSession(_ session: UserSession, forAccountId: String? = nil) {
        let key = forAccountId != nil ? "\(sessionKey)_\(forAccountId!)" : sessionKey
        if let data = try? JSONEncoder().encode(session) {
            _ = KeychainHelper.save(key: key, data: data)
            _ = KeychainHelper.save(key: sessionKey, data: data)
        }
    }
    
    public func loadSession(forAccountId: String? = nil) -> UserSession? {
        let key = forAccountId != nil ? "\(sessionKey)_\(forAccountId!)" : sessionKey
        guard let data = KeychainHelper.read(key: key) ?? KeychainHelper.read(key: sessionKey) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }
    
    public func clearSession() {
        _ = KeychainHelper.delete(key: sessionKey)
    }
    
    // MARK: - Isolated P2P Chats Persistence
    
    public func saveP2PChats(_ chats: [FeishuChatItem], forAccountId: String? = nil) {
        let accountId = forAccountId ?? activeAccountId ?? "default"
        let p2pOnly = chats.filter { $0.isP2P }
        if let data = try? JSONEncoder().encode(p2pOnly) {
            UserDefaults.standard.set(data, forKey: "\(p2pChatsPrefix)\(accountId)")
        }
    }
    
    public func loadP2PChats(forAccountId: String? = nil) -> [FeishuChatItem] {
        let accountId = forAccountId ?? activeAccountId ?? "default"
        guard let data = UserDefaults.standard.data(forKey: "\(p2pChatsPrefix)\(accountId)"),
              let list = try? JSONDecoder().decode([FeishuChatItem].self, from: data) else {
            return []
        }
        return list
    }
}
