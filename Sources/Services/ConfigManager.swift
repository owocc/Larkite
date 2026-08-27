import Foundation

@MainActor
public final class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()
    
    private let userDefaultsKey = "LarkNative_AppConfig"
    private let sessionKey = "LarkNative_UserSession"
    private let p2pChatsKey = "LarkNative_P2PChats"
    private let appSecretKeychainKey = "LarkNative_AppSecret"
    
    @Published public var config: AppConfig {
        didSet {
            saveConfig()
        }
    }
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(AppConfig.self, from: data) {
            var loaded = saved
            if let secret = KeychainHelper.readString(key: appSecretKeychainKey) {
                loaded.appSecret = secret
            }
            
            // Auto-merge missing essential IM scopes and remove legacy deprecated scopes
            var currentScopes = Set(loaded.scopes.components(separatedBy: " ").filter { !$0.isEmpty })
            currentScopes.remove("im:message.history:readonly") // Remove legacy key
            
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
    }
    
    public func saveSession(_ session: UserSession) {
        if let data = try? JSONEncoder().encode(session) {
            _ = KeychainHelper.save(key: sessionKey, data: data)
        }
    }
    
    public func loadSession() -> UserSession? {
        guard let data = KeychainHelper.read(key: sessionKey) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }
    
    public func clearSession() {
        _ = KeychainHelper.delete(key: sessionKey)
        UserDefaults.standard.removeObject(forKey: p2pChatsKey)
    }
    
    // MARK: - P2P Chats Persistence
    
    public func saveP2PChats(_ chats: [FeishuChatItem]) {
        let p2pOnly = chats.filter { $0.isP2P }
        if let data = try? JSONEncoder().encode(p2pOnly) {
            UserDefaults.standard.set(data, forKey: p2pChatsKey)
        }
    }
    
    public func loadP2PChats() -> [FeishuChatItem] {
        guard let data = UserDefaults.standard.data(forKey: p2pChatsKey),
              let list = try? JSONDecoder().decode([FeishuChatItem].self, from: data) else {
            return []
        }
        return list
    }
}
