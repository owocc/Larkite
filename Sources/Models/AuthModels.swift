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

/// Feishu Upload Image API Response
public struct FeishuUploadImageResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuUploadImageData?
}

public struct FeishuUploadImageData: Codable, Sendable {
    public let imageKey: String?
    
    enum CodingKeys: String, CodingKey {
        case imageKey = "image_key"
    }
}

public enum FeishuScopeCategory: String, CaseIterable, Identifiable, Sendable {
    case message = "消息与会话"
    case chat = "群组与群成员"
    case contact = "通讯录与用户"
    case system = "系统与凭证"
    
    public var id: String { rawValue }
}

public struct FeishuScopeInfo: Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let description: String
    public let category: FeishuScopeCategory
    public let isEssential: Bool
}

public enum FeishuScopes {
    public static let recommendedList: [FeishuScopeInfo] = [
        // 消息与会话
        FeishuScopeInfo(key: "im:message", name: "获取与发送单聊、群组消息", description: "接收和发送私聊与群聊消息", category: .message, isEssential: true),
        FeishuScopeInfo(key: "im:message:readonly", name: "读取单聊、群组消息", description: "只读获取私聊与群聊消息", category: .message, isEssential: true),
        FeishuScopeInfo(key: "im:message.p2p_msg:get_as_user", name: "以用户身份获取单聊消息", description: "以当前用户权限读取私聊消息", category: .message, isEssential: true),
        FeishuScopeInfo(key: "im:message.group_msg:get_as_user", name: "以用户身份获取群聊消息", description: "以当前用户权限读取群聊消息", category: .message, isEssential: true),
        FeishuScopeInfo(key: "im:message.send_as_user", name: "以用户身份发送消息", description: "以当前用户身份发送私聊/群聊消息", category: .message, isEssential: false),
        FeishuScopeInfo(key: "im:message:send_as_bot", name: "以应用身份发送消息", description: "以机器人身份发送消息", category: .message, isEssential: false),
        FeishuScopeInfo(key: "im:message:recall", name: "撤回消息", description: "撤回已发送的消息", category: .message, isEssential: false),
        FeishuScopeInfo(key: "im:message.reactions:write_only", name: "添加表情回复", description: "为消息添加 Emoji 点赞表情", category: .message, isEssential: false),
        
        FeishuScopeInfo(key: "im:resource", name: "上传与读取图片文件", description: "上传图片并在聊天中发送图片消息", category: .message, isEssential: true),
        // 群组与群成员
        FeishuScopeInfo(key: "im:chat", name: "获取与更新群信息", description: "获取群组属性并管理群组", category: .chat, isEssential: true),
        FeishuScopeInfo(key: "im:chat:readonly", name: "获取群信息 (只读)", description: "查询群名称、头像与属性", category: .chat, isEssential: true),
        FeishuScopeInfo(key: "im:chat.members:read", name: "查看群成员", description: "获取群内所有成员列表", category: .chat, isEssential: true),
        FeishuScopeInfo(key: "im:chat:create", name: "创建群组", description: "创建群聊与单聊会话", category: .chat, isEssential: false),
        
        // 通讯录与用户
        FeishuScopeInfo(key: "contact:user.base:readonly", name: "获取用户基本信息", description: "获取用户名、头像等基本资料", category: .contact, isEssential: true),
        FeishuScopeInfo(key: "contact:contact:readonly", name: "读取通讯录 (可选)", description: "获取企业全量通讯录以展示联系人目录（可选）", category: .contact, isEssential: false),
        FeishuScopeInfo(key: "contact:user.employee_id:readonly", name: "获取用户 ID", description: "读取 User ID / 工号", category: .contact, isEssential: false),
        
        // 系统与离线
        FeishuScopeInfo(key: "offline_access", name: "离线刷新凭证", description: "获取 refresh_token 以免频繁重复登录", category: .system, isEssential: true)
    ]
    
    public static var recommendedString: String {
        recommendedList.map(\.key).joined(separator: " ")
    }
    
    /// Minimal IM Scope (Only Chat, Messages, Group Members, User Profile - No Address Book needed)
    public static var minimalIMString: String {
        recommendedList.filter { $0.isEssential }.map(\.key).joined(separator: " ")
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
        scopes: FeishuScopes.minimalIMString,
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
