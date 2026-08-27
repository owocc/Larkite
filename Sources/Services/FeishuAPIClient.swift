import Foundation

/// Feishu OpenAPI & OAuth HTTP Client
public final class FeishuAPIClient: Sendable {
    public static let shared = FeishuAPIClient()
    
    private let session: URLSession
    
    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
    }
    
    public enum APIError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case feishuError(code: Int, msg: String)
        case decodingError(Error)
        case invalidResponse
        case unauthorized
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "请求 URL 无效"
            case .networkError(let error):
                return "网络请求异常: \(error.localizedDescription)"
            case .feishuError(let code, let msg):
                return "飞书接口返回错误 (\(code)): \(msg)"
            case .decodingError(let error):
                return "解析数据失败: \(error.localizedDescription)"
            case .invalidResponse:
                return "服务器响应异常"
            case .unauthorized:
                return "登录已失效，请重新授权"
            }
        }
    }
    
    // MARK: - OAuth Authorize URL
    
    public func buildAuthorizeURL(appId: String, redirectUri: String, scopes: String, state: String = UUID().uuidString) -> URL? {
        var components = URLComponents(string: "https://accounts.feishu.cn/open-apis/authen/v1/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: appId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components?.url
    }
    
    // MARK: - Token Exchange
    
    public func fetchUserAccessToken(
        appId: String,
        appSecret: String,
        code: String,
        redirectUri: String
    ) async throws -> FeishuTokenResponse {
        guard let url = URL(string: "https://open.feishu.cn/open-apis/authen/v2/oauth/token") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": appId,
            "client_secret": appSecret,
            "code": code,
            "redirect_uri": redirectUri
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse) != nil else {
            throw APIError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(FeishuTokenResponse.self, from: data)
        if decoded.code != 0 {
            let msg = decoded.errorDescription ?? decoded.error ?? decoded.msg ?? "未知错误"
            throw APIError.feishuError(code: decoded.code, msg: msg)
        }
        
        return decoded
    }
    
    public func refreshUserAccessToken(
        appId: String,
        appSecret: String,
        refreshToken: String
    ) async throws -> FeishuTokenResponse {
        guard let url = URL(string: "https://open.feishu.cn/open-apis/authen/v2/oauth/token") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": appId,
            "client_secret": appSecret,
            "refresh_token": refreshToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse) != nil else {
            throw APIError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(FeishuTokenResponse.self, from: data)
        if decoded.code != 0 {
            let msg = decoded.errorDescription ?? decoded.error ?? decoded.msg ?? "未知错误"
            throw APIError.feishuError(code: decoded.code, msg: msg)
        }
        
        return decoded
    }
    
    public func fetchTenantAccessToken(appId: String, appSecret: String) async throws -> String {
        guard let url = URL(string: "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "app_id": appId,
            "app_secret": appSecret
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(FeishuTenantTokenResponse.self, from: data)
        
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg ?? "获取 Tenant Access Token 失败")
        }
        
        guard let token = decoded.tenantAccessToken else {
            throw APIError.invalidResponse
        }
        
        return token
    }
    
    // MARK: - User Info
    
    public func fetchUserInfo(token: String) async throws -> FeishuUserInfo {
        guard let url = URL(string: "https://open.feishu.cn/open-apis/authen/v1/user_info") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuUserInfoResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        guard let userInfo = decoded.data else {
            throw APIError.invalidResponse
        }
        
        return userInfo
    }
    
    // MARK: - Chat / Group List
    
    public func fetchChatList(
        token: String,
        sortType: String = "ByActiveTimeDesc",
        pageToken: String? = nil,
        pageSize: Int = 50
    ) async throws -> FeishuChatListData {
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/im/v1/chats")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
            URLQueryItem(name: "sort_type", value: sortType)
        ]
        if let pageToken = pageToken, !pageToken.isEmpty {
            queryItems.append(URLQueryItem(name: "page_token", value: pageToken))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuChatListResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        return decoded.data ?? FeishuChatListData(items: [], pageToken: nil, hasMore: false)
    }
    
    /// Fetches all pages of user/bot chats
    public func fetchAllChats(token: String) async throws -> [FeishuChatItem] {
        var allItems: [FeishuChatItem] = []
        var currentToken: String? = nil
        var hasMore = true
        
        while hasMore {
            let data = try await fetchChatList(
                token: token,
                sortType: "ByActiveTimeDesc",
                pageToken: currentToken,
                pageSize: 50
            )
            
            if let items = data.items {
                allItems.append(contentsOf: items)
            }
            
            hasMore = data.hasMore ?? false
            currentToken = data.pageToken
            
            if currentToken == nil || currentToken?.isEmpty == true {
                break
            }
        }
        
        return allItems
    }
    
    /// Deep scan: traverses all chats and queries chat_mode (p2p vs group) for every chat
    public func scanAndHydrateAllChats(token: String) async -> [FeishuChatItem] {
        do {
            let allRawChats = try await fetchAllChats(token: token)
            return await hydrateChatsWithDetails(token: token, items: allRawChats)
        } catch {
            return []
        }
    }
    
    public func fetchChatInfo(token: String, chatId: String) async throws -> FeishuChatItem {
        let encodedId = chatId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chatId
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/chats/\(encodedId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuChatDetailResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        guard let item = decoded.data else {
            throw APIError.invalidResponse
        }
        
        return item
    }
    
    // MARK: - Chat Members
    
    public func fetchChatMembers(
        token: String,
        chatId: String,
        pageToken: String? = nil,
        pageSize: Int = 100
    ) async throws -> FeishuChatMemberListData {
        let encodedId = chatId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chatId
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/im/v1/chats/\(encodedId)/members")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "member_id_type", value: "open_id"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        if let pageToken = pageToken, !pageToken.isEmpty {
            queryItems.append(URLQueryItem(name: "page_token", value: pageToken))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuChatMemberListResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        return decoded.data ?? FeishuChatMemberListData(items: [], pageToken: nil, hasMore: false, memberTotal: nil)
    }
    
    /// Concurrently fetches full chat details (including chat_mode: p2p vs group) for a list of chats
    public func hydrateChatsWithDetails(
        token: String,
        items: [FeishuChatItem],
        maxConcurrency: Int = 8
    ) async -> [FeishuChatItem] {
        await withTaskGroup(of: (Int, FeishuChatItem).self, returning: [FeishuChatItem].self) { group in
            var results = items
            
            for (index, item) in items.enumerated() {
                group.addTask {
                    do {
                        var detail = try await self.fetchChatInfo(token: token, chatId: item.chatId)
                        
                        // If this is a P2P private chat, query members to extract peer name & ID
                        if detail.isP2P {
                            if let membersData = try? await self.fetchChatMembers(token: token, chatId: item.chatId, pageSize: 10),
                               let members = membersData.items, !members.isEmpty {
                                let currentUserId = await AppState.shared.session?.user?.openId
                                let peerMember = members.first(where: { $0.memberId != currentUserId }) ?? members.first
                                
                                if let peer = peerMember {
                                    let peerName = peer.name?.isEmpty == false ? peer.name! : peer.displayName
                                    detail = FeishuChatItem(
                                        chatId: detail.chatId,
                                        avatar: detail.avatar,
                                        name: peerName,
                                        description: "单聊 · \(peerName)",
                                        ownerId: peer.memberId,
                                        ownerIdType: "open_id",
                                        external: detail.external,
                                        tenantKey: detail.tenantKey,
                                        chatStatus: detail.chatStatus,
                                        chatMode: "p2p",
                                        chatType: "private",
                                        chatTag: detail.chatTag,
                                        userCount: detail.userCount ?? "\(members.count)",
                                        botCount: detail.botCount
                                    )
                                    
                                    await UserProfileManager.shared.registerUser(
                                        openId: peer.memberId,
                                        name: peerName
                                    )
                                }
                            }
                        }
                        
                        return (index, detail)
                    } catch {
                        return (index, item)
                    }
                }
            }
            
            for await (index, enrichedItem) in group {
                if index < results.count {
                    results[index] = enrichedItem
                }
            }
            
            return results
        }
    }
    
    /// Constructs or returns a P2P single chat representation for a user without creating any unwanted groups
    public func createOrGetP2PChat(
        token: String,
        receiveIdType: String,
        receiveId: String
    ) async throws -> FeishuChatItem {
        let resolvedName = await UserProfileManager.shared.resolveDisplayName(for: receiveId, currentUserId: nil)
        let displayName = resolvedName.hasPrefix("用户 (") ? "私聊 (\(receiveId.prefix(8)))" : resolvedName
        
        return FeishuChatItem(
            chatId: receiveId,
            avatar: nil,
            name: displayName,
            description: "单聊 · \(displayName)",
            ownerId: receiveId,
            ownerIdType: receiveIdType,
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
    
    // MARK: - Enterprise Contacts
    
    public func fetchContacts(
        token: String,
        pageToken: String? = nil,
        pageSize: Int = 50
    ) async throws -> FeishuContactListData {
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/contact/v3/users")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "user_id_type", value: "open_id"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        if let pageToken = pageToken, !pageToken.isEmpty {
            queryItems.append(URLQueryItem(name: "page_token", value: pageToken))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuContactListResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        return decoded.data ?? FeishuContactListData(hasMore: false, pageToken: nil, items: [])
    }
    
    public func fetchUserDetail(
        token: String,
        userId: String,
        userIdType: String = "open_id"
    ) async throws -> DetailedFeishuUser {
        let encodedId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/contact/v3/users/\(encodedId)")
        components?.queryItems = [
            URLQueryItem(name: "user_id_type", value: userIdType),
            URLQueryItem(name: "department_id_type", value: "open_department_id")
        ]
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let rawJsonString = String(data: data, encoding: .utf8)
        
        let decoded = try JSONDecoder().decode(FeishuUserDetailResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        guard var user = decoded.data?.user else {
            throw APIError.invalidResponse
        }
        
        user.rawJsonString = rawJsonString
        return user
    }
    
    // MARK: - Chat Messages History
    
    public func fetchChatMessages(
        token: String,
        chatId: String,
        sortType: String = "ByCreateTimeAsc",
        pageToken: String? = nil,
        pageSize: Int = 40
    ) async throws -> FeishuMessageListData {
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/im/v1/messages")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "container_id_type", value: "chat"),
            URLQueryItem(name: "container_id", value: chatId),
            URLQueryItem(name: "sort_type", value: sortType),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        if let pageToken = pageToken, !pageToken.isEmpty {
            queryItems.append(URLQueryItem(name: "page_token", value: pageToken))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuMessageListResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        return decoded.data ?? FeishuMessageListData(items: [], pageToken: nil, hasMore: false)
    }
    
    /// Fetches the latest single message for a chat (for preview snippets in chat list)
    public func fetchLatestMessage(token: String, chatId: String) async -> FeishuMessageItem? {
        do {
            let data = try await fetchChatMessages(
                token: token,
                chatId: chatId,
                sortType: "ByCreateTimeDesc",
                pageToken: nil,
                pageSize: 1
            )
            return data.items?.first
        } catch {
            return nil
        }
    }
    
    /// Concurrently fetches latest messages for a batch of chats with bounded parallel execution
    public func batchFetchLatestMessages(token: String, chatIds: [String]) async -> [String: FeishuMessageItem] {
        await withTaskGroup(of: (String, FeishuMessageItem?).self, returning: [String: FeishuMessageItem].self) { group in
            for chatId in chatIds {
                if chatId.hasPrefix("oc_") {
                    group.addTask {
                        let msg = await self.fetchLatestMessage(token: token, chatId: chatId)
                        return (chatId, msg)
                    }
                }
            }
            
            var results: [String: FeishuMessageItem] = [:]
            for await (chatId, msg) in group {
                if let message = msg {
                    results[chatId] = message
                }
            }
            return results
        }
    }
    
    public func fetchSingleMessage(
        token: String,
        messageId: String
    ) async throws -> FeishuMessageItem {
        let encodedId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageId
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/messages/\(encodedId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuMessageListResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        guard let msg = decoded.data?.items?.first else {
            throw APIError.invalidResponse
        }
        
        return msg
    }
    
    
    // MARK: - Image Upload & Image Message
    
    public func uploadImage(
        token: String,
        imageData: Data,
        fileName: String = "image.png",
        mimeType: String = "image/png"
    ) async throws -> String {
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/images") else {
            throw APIError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // image_type="message"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("message\r\n".data(using: .utf8)!)
        
        // image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse) != nil else {
            throw APIError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(FeishuUploadImageResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        guard let key = decoded.data?.imageKey else {
            throw APIError.invalidResponse
        }
        
        return key
    }
    
    public func sendImageMessage(
        token: String,
        receiveIdType: String,
        receiveId: String,
        imageKey: String
    ) async throws -> FeishuMessageItem {
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/im/v1/messages")
        components?.queryItems = [
            URLQueryItem(name: "receive_id_type", value: receiveIdType)
        ]
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let contentString = "{\"image_key\":\"\(imageKey)\"}"
        let body: [String: Any] = [
            "receive_id": receiveId,
            "msg_type": "image",
            "content": contentString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse) != nil else {
            throw APIError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(FeishuSingleMessageResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        guard let msg = decoded.data else {
            throw APIError.invalidResponse
        }
        return msg
    }
    
    public func replyImageMessage(
        token: String,
        messageId: String,
        imageKey: String
    ) async throws -> FeishuMessageItem {
        let encodedId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageId
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/messages/\(encodedId)/reply") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let contentString = "{\"image_key\":\"\(imageKey)\"}"
        let body: [String: Any] = [
            "msg_type": "image",
            "content": contentString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse) != nil else {
            throw APIError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(FeishuSingleMessageResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        guard let msg = decoded.data else {
            throw APIError.invalidResponse
        }
        return msg
    }
    // MARK: - Send / Reply / Recall / Reactions
    
    public func sendMessage(
        token: String,
        receiveIdType: String,
        receiveId: String,
        text: String
    ) async throws -> FeishuMessageItem {
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/im/v1/messages")
        components?.queryItems = [
            URLQueryItem(name: "receive_id_type", value: receiveIdType)
        ]
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let contentJson = try JSONSerialization.data(withJSONObject: ["text": text])
        let contentString = String(data: contentJson, encoding: .utf8) ?? "{\"text\":\"\(text)\"}"
        
        let body: [String: Any] = [
            "receive_id": receiveId,
            "msg_type": "text",
            "content": contentString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuSingleMessageResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        guard let msg = decoded.data else {
            throw APIError.invalidResponse
        }
        
        return msg
    }
    
    public func replyMessage(
        token: String,
        messageId: String,
        text: String
    ) async throws -> FeishuMessageItem {
        let encodedId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageId
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/messages/\(encodedId)/reply") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let contentJson = try JSONSerialization.data(withJSONObject: ["text": text])
        let contentString = String(data: contentJson, encoding: .utf8) ?? "{\"text\":\"\(text)\"}"
        
        let body: [String: Any] = [
            "msg_type": "text",
            "content": contentString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(FeishuSingleMessageResponse.self, from: data)
        if decoded.code != 0 {
            throw APIError.feishuError(code: decoded.code, msg: decoded.msg)
        }
        
        guard let msg = decoded.data else {
            throw APIError.invalidResponse
        }
        
        return msg
    }
    
    public func recallMessage(
        token: String,
        messageId: String
    ) async throws {
        let encodedId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageId
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/messages/\(encodedId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? Int, code != 0 {
            let msg = json["msg"] as? String ?? "撤回消息失败"
            throw APIError.feishuError(code: code, msg: msg)
        }
    }
    
    public func addMessageReaction(
        token: String,
        messageId: String,
        emojiType: String
    ) async throws {
        let encodedId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageId
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/messages/\(encodedId)/reactions") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "reaction_type": [
                "emoji_type": emojiType
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? Int, code != 0 {
            let msg = json["msg"] as? String ?? "添加表情回复失败"
            throw APIError.feishuError(code: code, msg: msg)
        }
    }
    
    // MARK: - Message Resource & Image
    
    public func fetchMessageResource(
        token: String,
        messageId: String,
        fileKey: String,
        type: String = "image"
    ) async throws -> Data {
        let encodedMsgId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageId
        let encodedFileKey = fileKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileKey
        
        var components = URLComponents(string: "https://open.feishu.cn/open-apis/im/v1/messages/\(encodedMsgId)/resources/\(encodedFileKey)")
        components?.queryItems = [
            URLQueryItem(name: "type", value: type)
        ]
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode != 200 {
            // Try decode error JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["code"] as? Int,
               let msg = json["msg"] as? String {
                throw APIError.feishuError(code: code, msg: msg)
            }
            throw APIError.invalidResponse
        }
        
        return data
    }
    
    public func downloadImage(
        token: String,
        imageKey: String
    ) async throws -> Data {
        let encodedKey = imageKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? imageKey
        guard let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/images/\(encodedKey)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["code"] as? Int,
               let msg = json["msg"] as? String {
                throw APIError.feishuError(code: code, msg: msg)
            }
            throw APIError.invalidResponse
        }
        
        return data
    }
}
