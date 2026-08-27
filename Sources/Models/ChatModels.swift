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

/// Feishu Single Chat Detail API Response
public struct FeishuChatDetailResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuChatItem?
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
    public let chatMode: String?
    public let chatType: String?
    public let chatTag: String?
    public let userCount: String?
    public let botCount: String?
    
    public var isP2P: Bool {
        chatMode == "p2p"
    }
    
    public var displayName: String {
        if let name = name, !name.isEmpty { return name }
        if isP2P {
            return "私聊会话 (\(chatId.prefix(8)))"
        }
        return "未命名群组 (\(chatId.prefix(8)))"
    }
    
    public func resolvedDisplayName(currentUserName: String?, currentUserId: String?) -> String {
        if isP2P {
            if let name = name, !name.isEmpty, name != currentUserName {
                return name
            }
            if let desc = description, !desc.isEmpty, desc != "单聊会话", desc != currentUserName {
                return desc
            }
            if let owner = ownerId, owner != currentUserId {
                return "用户 (\(owner.prefix(6)))"
            }
            return "私聊 (\(chatId.prefix(8)))"
        }
        if let name = name, !name.isEmpty { return name }
        return "未命名群组 (\(chatId.prefix(8)))"
    }
    
    public func resolvedAvatarUrl(currentUserId: String?) -> String? {
        if isP2P {
            if let owner = ownerId, owner != currentUserId {
                // Peer avatar if available
                return avatar
            }
        }
        return avatar
    }
    
    public var isExternal: Bool {
        external ?? false
    }
    
    public var isDissolved: Bool {
        chatStatus == "dissolved" || chatStatus == "dissolved_save"
    }
    
    public var modeDescription: String {
        switch chatMode {
        case "p2p": return "单聊 / 私聊"
        case "group": return "群聊"
        case "topic": return "话题群"
        default: return isP2P ? "单聊 / 私聊" : "群聊"
        }
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
        case chatMode = "chat_mode"
        case chatType = "chat_type"
        case chatTag = "chat_tag"
        case userCount = "user_count"
        case botCount = "bot_count"
    }
}
