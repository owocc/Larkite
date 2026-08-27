import Foundation

/// Feishu Chat List API Response
public struct FeishuChatListResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuChatListData?
}

public struct FeishuChatListData: Codable, Sendable {
    public let items: [FeishuChatItem]?
    public let pageToken: String?
    public let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case items
        case pageToken = "page_token"
        case hasMore = "has_more"
    }
}

/// Single Chat / Group item
public struct FeishuChatItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { chatId }
    
    public let chatId: String
    public let avatar: String?
    public let name: String?
    public let description: String?
    public let ownerId: String?
    public let ownerIdType: String?
    public let external: Bool?
    public let tenantKey: String?
    public let chatStatus: String?
    
    public var displayName: String {
        if let name = name, !name.isEmpty { return name }
        return "未命名群组 (\(chatId.prefix(8)))"
    }
    
    public var isExternal: Bool {
        external ?? false
    }
    
    public var isDissolved: Bool {
        chatStatus == "dissolved" || chatStatus == "dissolved_save"
    }
    
    public var statusDescription: String {
        switch chatStatus {
        case "normal": return "正常"
        case "dissolved": return "已解散"
        case "dissolved_save": return "已解散并归档"
        default: return "正常"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case avatar
        case name
        case description
        case ownerId = "owner_id"
        case ownerIdType = "owner_id_type"
        case external
        case tenantKey = "tenant_key"
        case chatStatus = "chat_status"
    }
}
