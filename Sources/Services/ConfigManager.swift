import Foundation
import SwiftUI

public enum ThemeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "跟随系统"
    case light = "浅色模式"
    case dark = "深色模式"
    
    public var id: String { rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public enum AccentColorChoice: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "系统主色"
    case blue = "飞书蓝"
    case green = "消息绿"
    case purple = "极光紫"
    case orange = "活力橙"
    case pink = "珊瑚粉"
    case cyan = "青碧蓝"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .system:
            return Color.accentColor
        case .blue:
            return Color(hex: "3370FF")
        case .green:
            return Color(hex: "34C759")
        case .purple:
            return Color(hex: "AF52DE")
        case .orange:
            return Color(hex: "FF9500")
        case .pink:
            return Color(hex: "FF2D55")
        case .cyan:
            return Color(hex: "32ADE6")
        }
    }
}
@MainActor
public final class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()
    
    private let themeModeKey = "LarkNative_ThemeMode"
    private let accentColorKey = "LarkNative_AccentColor"
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
    @Published public var themeMode: ThemeMode = .system {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
        }
    }
    @Published public var accentColorChoice: AccentColorChoice = .system {
        didSet {
            UserDefaults.standard.set(accentColorChoice.rawValue, forKey: accentColorKey)
        }
    }
    private init() {
        // 0. Load theme mode & accent color
        if let raw = UserDefaults.standard.string(forKey: themeModeKey),
           let savedTheme = ThemeMode(rawValue: raw) {
            self.themeMode = savedTheme
        } else {
            self.themeMode = .system
        }
        
        if let rawAccent = UserDefaults.standard.string(forKey: accentColorKey),
           let savedAccent = AccentColorChoice(rawValue: rawAccent) {
            self.accentColorChoice = savedAccent
        } else {
            self.accentColorChoice = .system
        }
        // 1. Load active account ID
        let savedActiveId = UserDefaults.standard.string(forKey: activeAccountIdKey)
        self.activeAccountId = savedActiveId
        // 2. Load accounts list
        let loadedAccounts: [AccountSession]
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let list = try? JSONDecoder().decode([AccountSession].self, from: data) {
            loadedAccounts = list
        } else {
            loadedAccounts = []
        }
        self.accounts = loadedAccounts
        
        // 3. Load active account config or fallback default
        if let activeId = savedActiveId,
           let activeAccount = loadedAccounts.first(where: { $0.id == activeId }) {
            var loaded = activeAccount.config
            if let secret = KeychainHelper.readString(key: "\(appSecretKeychainKey)_\(activeId)") ?? KeychainHelper.readString(key: appSecretKeychainKey) {
                loaded.appSecret = secret
            }
            self.config = loaded
        } else if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
                  let saved = try? JSONDecoder().decode(AppConfig.self, from: data) {
            var loaded = saved
            if let secret = KeychainHelper.readString(key: appSecretKeychainKey) {
                loaded.appSecret = secret
            }
            self.config = loaded
        } else {
            self.config = .default
        }
    }
    
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
        
        let accountName = user?.displayName ?? "飞书账号 (\(config.appId.prefix(6)))"
        
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
        
        // Save isolated Keychain secret & session & config
        if !config.appSecret.isEmpty {
            _ = KeychainHelper.saveString(key: "\(appSecretKeychainKey)_\(accountId)", value: config.appSecret)
        }
        saveSession(session, forAccountId: accountId)
        saveAccountConfig(config, forAccountId: accountId)
        persistAccounts()
        
        return account
    }
    
    public func switchAccount(to accountId: String) -> AccountSession? {
        guard let account = accounts.first(where: { $0.id == accountId }) else { return nil }
        self.activeAccountId = accountId
        
        // Load isolated credentials for this account
        var accountConfig = account.config
        if let secret = KeychainHelper.readString(key: "\(appSecretKeychainKey)_\(accountId)") {
            accountConfig.appSecret = secret
        }
        self.config = accountConfig
        
        if let idx = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[idx].lastActiveAt = Date()
            accounts[idx].config = accountConfig
        }
        
        persistAccounts()
        return account
    }
    
    public func removeAccount(id: String) {
        accounts.removeAll(where: { $0.id == id })
        _ = KeychainHelper.delete(key: "\(sessionKey)_\(id)")
        _ = KeychainHelper.delete(key: "\(appSecretKeychainKey)_\(id)")
        UserDefaults.standard.removeObject(forKey: "\(userDefaultsKey)_\(id)")
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
            _ = KeychainHelper.delete(key: "\(appSecretKeychainKey)_\(acc.id)")
            UserDefaults.standard.removeObject(forKey: "\(userDefaultsKey)_\(acc.id)")
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
    
    // MARK: - Isolated Config Storage
    
    public func saveAccountConfig(_ cfg: AppConfig, forAccountId: String) {
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: "\(userDefaultsKey)_\(forAccountId)")
        }
    }
    
    public func loadAccountConfig(forAccountId: String) -> AppConfig? {
        guard let data = UserDefaults.standard.data(forKey: "\(userDefaultsKey)_\(forAccountId)"),
              var cfg = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return nil
        }
        if let secret = KeychainHelper.readString(key: "\(appSecretKeychainKey)_\(forAccountId)") {
            cfg.appSecret = secret
        }
        return cfg
    }
    
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        if !config.appSecret.isEmpty {
            _ = KeychainHelper.saveString(key: appSecretKeychainKey, value: config.appSecret)
        }
        
        if let activeId = activeAccountId, let idx = accounts.firstIndex(where: { $0.id == activeId }) {
            accounts[idx].config = config
            saveAccountConfig(config, forAccountId: activeId)
            if !config.appSecret.isEmpty {
                _ = KeychainHelper.saveString(key: "\(appSecretKeychainKey)_\(activeId)", value: config.appSecret)
            }
            persistAccounts()
        }
    }
    
    public func resetToMinimalIMScopes() {
        self.config.scopes = FeishuScopes.minimalIMString
        saveConfig()
    }
    
    public func resetToRecommendedScopes() {
        self.config.scopes = FeishuScopes.recommendedString
        saveConfig()
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
