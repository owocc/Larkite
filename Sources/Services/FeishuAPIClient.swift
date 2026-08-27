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
