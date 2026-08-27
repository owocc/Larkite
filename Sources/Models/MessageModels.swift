import Foundation

/// Feishu Message History List Response
public struct FeishuMessageListResponse: Codable, Sendable {
    public let code: Int
    public let msg: String
    public let data: FeishuMessageListData?
}

public struct FeishuMessageListData: Codable, Sendable {
    public let items: [FeishuMessageItem]?
    public let pageToken: String?
    public let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case items
        case pageToken = "page_token"
        case hasMore = "has_more"
    }
}

/// Message Sender Info
public struct MessageSender: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let idType: String?
    public let senderType: String?
    public let tenantKey: String?
    
    public var isUser: Bool {
        senderType == "user"
    }
    
    public var isAppOrBot: Bool {
        senderType == "app"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case idType = "id_type"
        case senderType = "sender_type"
        case tenantKey = "tenant_key"
    }
}

/// Message Mention Info
public struct MessageMention: Codable, Equatable, Hashable, Sendable {
    public let key: String
    public let id: String
    public let idType: String?
    public let name: String?
    public let tenantKey: String?
    
    enum CodingKeys: String, CodingKey {
        case key
        case id
        case idType = "id_type"
        case name
        case tenantKey = "tenant_key"
    }
}

/// Message Body
public struct MessageBody: Codable, Equatable, Hashable, Sendable {
    public let content: String?
}

/// Single Feishu Message Item
public struct FeishuMessageItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { messageId }
    
    public let messageId: String
    public let rootId: String?
    public let parentId: String?
    public let threadId: String?
    public let msgType: String
    public let createTime: String
    public let updateTime: String?
    public let deleted: Bool?
    public let updated: Bool?
    public let chatId: String?
    public let sender: MessageSender?
    public let body: MessageBody?
    public let mentions: [MessageMention]?
    public let upperMessageId: String?
    
    public var isDeletedOrRecalled: Bool {
        deleted ?? false
    }
    
    public var createdDate: Date {
        if let ms = Double(createTime) {
            return Date(timeIntervalSince1970: ms / 1000.0)
        }
        return Date()
    }
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: createdDate)
    }
    
    public var formattedDateHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(createdDate) {
            return "今天"
        } else if calendar.isDateInYesterday(createdDate) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: createdDate)
        }
    }
    
    public var parsedContent: ParsedMessageContent {
        if isDeletedOrRecalled {
            return .recalled
        }
        
        guard let contentString = body?.content, !contentString.isEmpty else {
            return .empty
        }
        
        guard let data = contentString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .rawText(contentString)
        }
        
        switch msgType {
        case "text":
            let text = json["text"] as? String ?? ""
            return .text(text)
            
        case "image":
            let imageKey = json["image_key"] as? String ?? ""
            return .image(imageKey: imageKey)
            
        case "file":
            let fileKey = json["file_key"] as? String ?? ""
            let fileName = json["file_name"] as? String ?? "未知文件"
            let fileSize = json["file_size"] as? Int
            return .file(fileKey: fileKey, fileName: fileName, fileSize: fileSize)
            
        case "audio":
            let fileKey = json["file_key"] as? String ?? ""
            let duration = json["duration"] as? Int
            return .audio(fileKey: fileKey, durationMs: duration)
            
        case "media":
            let fileKey = json["file_key"] as? String ?? ""
            let imageKey = json["image_key"] as? String
            let fileName = json["file_name"] as? String
            let duration = json["duration"] as? Int
            return .media(fileKey: fileKey, imageKey: imageKey, fileName: fileName, durationSec: duration)
            
        case "post":
            return parsePostContent(json)
            
        case "interactive", "card":
            return .card(rawJson: contentString)
            
        case "share_chat":
            let chatId = json["chat_id"] as? String ?? ""
            return .shareChat(chatId: chatId)
            
        case "system":
            let text = json["text"] as? String ?? contentString
            return .system(text)
            
        default:
            return .unsupported(type: msgType, raw: contentString)
        }
    }
    
    private func parsePostContent(_ json: [String: Any]) -> ParsedMessageContent {
        // Post format can have "zh_cn", "en_us", or direct "title" & "content"
        let localeDict = json["zh_cn"] as? [String: Any] ?? json["en_us"] as? [String: Any] ?? json
        let title = localeDict["title"] as? String
        var segments: [PostSegment] = []
        
        if let contentArray = localeDict["content"] as? [[[String: Any]]] {
            for line in contentArray {
                for element in line {
                    let tag = element["tag"] as? String ?? "text"
                    switch tag {
                    case "text":
                        if let text = element["text"] as? String {
                            segments.append(.text(text))
                        }
                    case "a":
                        let text = element["text"] as? String ?? element["href"] as? String ?? ""
                        let href = element["href"] as? String ?? ""
                        segments.append(.link(text: text, url: href))
                    case "at":
                        let userName = element["user_name"] as? String ?? element["user_id"] as? String ?? "用户"
                        segments.append(.mention(name: userName))
                    case "img":
                        let imageKey = element["image_key"] as? String ?? ""
                        segments.append(.image(imageKey: imageKey))
                    default:
                        if let text = element["text"] as? String {
                            segments.append(.text(text))
                        }
                    }
                }
                segments.append(.lineBreak)
            }
        }
        
        return .post(title: title, segments: segments)
    }
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case rootId = "root_id"
        case parentId = "parent_id"
        case threadId = "thread_id"
        case msgType = "msg_type"
        case createTime = "create_time"
        case updateTime = "update_time"
        case deleted
        case updated
        case chatId = "chat_id"
        case sender
        case body
        case mentions
        case upperMessageId = "upper_message_id"
    }
}

/// Parsed High-level Message Enum
public enum ParsedMessageContent: Equatable, Hashable, Sendable {
    case text(String)
    case image(imageKey: String)
    case file(fileKey: String, fileName: String, fileSize: Int?)
    case audio(fileKey: String, durationMs: Int?)
    case media(fileKey: String, imageKey: String?, fileName: String?, durationSec: Int?)
    case post(title: String?, segments: [PostSegment])
    case card(rawJson: String)
    case shareChat(chatId: String)
    case system(String)
    case recalled
    case empty
    case rawText(String)
    case unsupported(type: String, raw: String)
}

public enum PostSegment: Equatable, Hashable, Sendable {
    case text(String)
    case link(text: String, url: String)
    case mention(name: String)
    case image(imageKey: String)
    case lineBreak
}
