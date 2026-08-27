import Foundation

@MainActor
public final class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()
    
    private let userDefaultsKey = "LarkNative_AppConfig"
    private let sessionKey = "LarkNative_UserSession"
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
            self.config = loaded
        } else {
            self.config = .default
        }
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
    }
}
