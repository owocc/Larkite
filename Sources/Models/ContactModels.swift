import Foundation

/// Feishu Contact Users List API Response
public struct FeishuContactListResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuContactListData?
}

public struct FeishuContactListData: Codable, Sendable {
    public let hasMore: Bool?
    public let pageToken: String?
    public let items: [FeishuContactUser]?
    
    enum CodingKeys: String, CodingKey {
        case hasMore = "has_more"
        case pageToken = "page_token"
        case items
    }
}

public struct FeishuContactAvatar: Codable, Equatable, Hashable, Sendable {
    public let avatar72: String?
    public let avatar240: String?
    public let avatar640: String?
    public let avatarOrigin: String?
    
    public var bestUrl: String? {
        avatar240 ?? avatar72 ?? avatar640 ?? avatarOrigin
    }
    
    enum CodingKeys: String, CodingKey {
        case avatar72 = "avatar_72"
        case avatar240 = "avatar_240"
        case avatar640 = "avatar_640"
        case avatarOrigin = "avatar_origin"
    }
}

/// Single Enterprise Contact User
public struct FeishuContactUser: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { openId ?? userId ?? unionId ?? UUID().uuidString }
    
    public let openId: String?
    public let userId: String?
    public let unionId: String?
    public let name: String?
    public let enName: String?
    public let email: String?
    public let enterpriseEmail: String?
    public let mobile: String?
    public let jobTitle: String?
    public let city: String?
    public let avatar: FeishuContactAvatar?
    
    public var displayName: String {
        if let name = name, !name.isEmpty { return name }
        if let enName = enName, !enName.isEmpty { return enName }
        return "联系人 (\(id.prefix(6)))"
    }
    
    public var bestAvatarUrl: String? {
        avatar?.bestUrl
    }
    
    /// Converts a contact into a FeishuChatItem for direct P2P messaging
    public func toP2PChatItem() -> FeishuChatItem {
        FeishuChatItem(
            chatId: openId ?? id,
            avatar: bestAvatarUrl,
            name: displayName,
            description: jobTitle ?? email ?? "单聊联系人",
            ownerId: openId ?? userId,
            ownerIdType: "open_id",
            external: false,
            tenantKey: nil,
            chatStatus: "normal",
            chatMode: "p2p",
            chatType: "private",
            chatTag: "p2p",
            userCount: "2",
            botCount: "0"
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case openId = "open_id"
        case userId = "user_id"
        case unionId = "union_id"
        case name
        case enName = "en_name"
        case email
        case enterpriseEmail = "enterprise_email"
        case mobile
        case jobTitle = "job_title"
        case city
        case avatar
    }
}
