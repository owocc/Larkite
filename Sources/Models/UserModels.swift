import Foundation

/// Feishu User Info Response
public struct FeishuUserInfoResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuUserInfo?
}

/// Detailed Feishu User Info
public struct FeishuUserInfo: Codable, Equatable, Identifiable, Sendable {
    public var id: String { openId ?? userId ?? unionId ?? "unknown" }
    
    public let name: String?
    public let enName: String?
    public let avatarUrl: String?
    public let avatarThumb: String?
    public let avatarMiddle: String?
    public let avatarBig: String?
    public let openId: String?
    public let unionId: String?
    public let email: String?
    public let enterpriseEmail: String?
    public let userId: String?
    public let mobile: String?
    public let tenantKey: String?
    public let employeeNo: String?
    
    public var displayName: String {
        if let name = name, !name.isEmpty { return name }
        if let enName = enName, !enName.isEmpty { return enName }
        return "飞书用户"
    }
    
    public var bestAvatarUrl: String? {
        avatarMiddle ?? avatarThumb ?? avatarBig ?? avatarUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case enName = "en_name"
        case avatarUrl = "avatar_url"
        case avatarThumb = "avatar_thumb"
        case avatarMiddle = "avatar_middle"
        case avatarBig = "avatar_big"
        case openId = "open_id"
        case unionId = "union_id"
        case email
        case enterpriseEmail = "enterprise_email"
        case userId = "user_id"
        case mobile
        case tenantKey = "tenant_key"
        case employeeNo = "employee_no"
    }
}
