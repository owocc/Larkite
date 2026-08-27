import Foundation

/// Saved Account Profile for Multi-Account support
public struct AccountSession: Codable, Identifiable, Equatable, Sendable {
    public let id: String // Unique account id (e.g. open_id, user_id, or app_id)
    public var name: String
    public var enName: String?
    public var avatarUrl: String?
    public var email: String?
    public var mobile: String?
    public var tenantKey: String?
    public var tokenType: UserSession.TokenType
    public var session: UserSession
    public var config: AppConfig
    public var createdAt: Date
    public var lastActiveAt: Date
    
    public init(
        id: String,
        name: String,
        enName: String? = nil,
        avatarUrl: String? = nil,
        email: String? = nil,
        mobile: String? = nil,
        tenantKey: String? = nil,
        tokenType: UserSession.TokenType,
        session: UserSession,
        config: AppConfig,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.enName = enName
        self.avatarUrl = avatarUrl
        self.email = email
        self.mobile = mobile
        self.tenantKey = tenantKey
        self.tokenType = tokenType
        self.session = session
        self.config = config
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
    
    public var displayName: String {
        if !name.isEmpty { return name }
        if let en = enName, !en.isEmpty { return en }
        return "飞书账号 (\(id.prefix(6)))"
    }
}
