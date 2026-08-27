import Foundation

/// Feishu Chat Members List API Response
public struct FeishuChatMemberListResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuChatMemberListData?
}

public struct FeishuChatMemberListData: Codable, Sendable {
    public let items: [FeishuChatMemberItem]?
    public let pageToken: String?
    public let hasMore: Bool?
    public let memberTotal: Int?
    
    enum CodingKeys: String, CodingKey {
        case items
        case pageToken = "page_token"
        case hasMore = "has_more"
        case memberTotal = "member_total"
    }
}

/// Single Group Member Item
public struct FeishuChatMemberItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { memberId }
    
    public let memberId: String
    public let memberIdType: String?
    public let name: String?
    public let tenantKey: String?
    
    public var displayName: String {
        if let name = name, !name.isEmpty { return name }
        return "成员 (\(memberId.prefix(6)))"
    }
    
    public func isOwner(ownerId: String?) -> Bool {
        guard let ownerId = ownerId, !ownerId.isEmpty else { return false }
        return memberId == ownerId
    }
    
    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case memberIdType = "member_id_type"
        case name
        case tenantKey = "tenant_key"
    }
}
