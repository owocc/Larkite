import Foundation

/// Feishu OAuth Token Response
public struct FeishuTokenResponse: Codable, Sendable {
    public let code: Int
    public let msg: String?
    public let error: String?
    public let errorDescription: String?
    public let accessToken: String?
    public let expiresIn: Int?
    public let refreshToken: String?
    public let refreshTokenExpiresIn: Int?
    public let tokenType: String?
    public let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case code
        case msg
        case error
        case errorDescription = "error_description"
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
        case tokenType = "token_type"
        case scope
    }
}

/// Tenant Access Token Response
public struct FeishuTenantTokenResponse: Codable, Sendable {
    public let code: Int
    public let msg: String?
    public let tenantAccessToken: String?
    public let expire: Int?
    
    enum CodingKeys: String, CodingKey {
        case code
        case msg
        case tenantAccessToken = "tenant_access_token"
        case expire
    }
}

/// App Configuration for Feishu OAuth
public struct AppConfig: Codable, Equatable, Sendable {
    public var appId: String
    public var appSecret: String
    public var redirectUri: String
    public var scopes: String
    public var port: UInt16
    
    public static let `default` = AppConfig(
        appId: "",
        appSecret: "",
        redirectUri: "http://127.0.0.1:8989/callback",
        scopes: "im:chat im:chat:readonly contact:user.base:readonly offline_access",
        port: 8989
    )
}

/// Active Session Token
public struct UserSession: Codable, Equatable, Sendable {
    public var tokenType: TokenType
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
    public var user: FeishuUserInfo?
    
    public enum TokenType: String, Codable, Sendable {
        case userAccessToken = "user_access_token"
        case tenantAccessToken = "tenant_access_token"
        case directToken = "direct_token"
    }
    
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
}
