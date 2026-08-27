import SwiftUI

@MainActor
public final class DebugViewModel: ObservableObject {
    @Published public var endpoint: String = "https://open.feishu.cn/open-apis/im/v1/chats?page_size=20"
    @Published public var httpMethod: String = "GET"
    @Published public var responseBody: String = ""
    @Published public var statusCode: Int? = nil
    @Published public var responseTimeMs: Double? = nil
    @Published public var isLoading: Bool = false
    
    public init() {}
    
    public func executeRequest(token: String?) async {
        guard let token = token, !token.isEmpty, let url = URL(string: endpoint) else {
            responseBody = "错误: 缺少登录 Token 或 URL 无效"
            return
        }
        
        isLoading = true
        let start = Date()
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(start) * 1000
            
            if let httpResp = response as? HTTPURLResponse {
                self.statusCode = httpResp.statusCode
                self.responseTimeMs = elapsed
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                self.responseBody = prettyString
            } else {
                self.responseBody = String(data: data, encoding: .utf8) ?? "无法解析返回内容"
            }
        } catch {
            self.responseBody = "请求发生错误: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

public struct DebugView: View {
    @ObservedObject var appState: AppState = .shared
    @StateObject private var viewModel = DebugViewModel()
    
    private let presetEndpoints = [
        ("群列表", "https://open.feishu.cn/open-apis/im/v1/chats?page_size=20"),
        ("用户信息", "https://open.feishu.cn/open-apis/authen/v1/user_info"),
        ("企业信息", "https://open.feishu.cn/open-apis/tenant/v2/tenant/query")
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Feishu OpenAPI 调试台")
                        .font(.system(size: 20, weight: .bold))
                    Text("直接使用当前登录 Token 向飞书服务器发送请求")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Endpoint Presets
            HStack(spacing: 8) {
                Text("快捷模板:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                ForEach(presetEndpoints, id: \.0) { name, url in
                    Button(name) {
                        viewModel.endpoint = url
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Spacer()
            }
            
            // Request bar
            HStack(spacing: 8) {
                Picker("", selection: $viewModel.httpMethod) {
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                }
                .frame(width: 80)
                
                TextField("https://open.feishu.cn/open-apis/...", text: $viewModel.endpoint)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                
                PrimaryGradientButton("发送请求", icon: "paperplane.fill", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.executeRequest(token: appState.session?.accessToken)
                    }
                }
            }
            
            // Status bar
            if let status = viewModel.statusCode {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("HTTP 状态:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("\(status)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(status == 200 ? .green : .red)
                    }
                    
                    if let time = viewModel.responseTimeMs {
                        HStack(spacing: 4) {
                            Text("耗时:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f ms", time))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            
            // Response Viewer
            ScrollView([.horizontal, .vertical]) {
                Text(viewModel.responseBody.isEmpty ? "// 点击「发送请求」查看飞书返回的 JSON 数据" : viewModel.responseBody)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(viewModel.responseBody.isEmpty ? .secondary : .primary)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
