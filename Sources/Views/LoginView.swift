import SwiftUI
import AppKit

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var selectedLoginTab: Int = 0
    @Published public var directTokenInput: String = ""
    @Published public var directTokenType: UserSession.TokenType = .userAccessToken
    @Published public var manualCodeInput: String = ""
    @Published public var showManualCodeInput: Bool = false
    @Published public var copiedCallbackToast: Bool = false
    
    public init() {}
    
    public func copyCallbackUrl(url: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
        
        withAnimation {
            copiedCallbackToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation {
                self?.copiedCallbackToast = false
            }
        }
    }
}

public struct LoginView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = LoginViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Ambient Background
            backgroundGradient
            
            VStack(spacing: 24) {
                // Header Brand
                headerView
                
                // Local Server Status Banner
                localServerBanner
                    .frame(maxWidth: 480)
                
                // Login Card
                GlassCard(cornerRadius: 24, padding: 24) {
                    VStack(spacing: 20) {
                        // Login Modes Segmented Control
                        Picker("", selection: $viewModel.selectedLoginTab) {
                            Text("飞书网页授权").tag(0)
                            Text("自建应用免登录").tag(1)
                            Text("Direct Token").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)
                        
                        // Mode Content
                        if viewModel.selectedLoginTab == 0 {
                            oauthLoginSection
                        } else if viewModel.selectedLoginTab == 1 {
                            appCredentialsSection
                        } else {
                            directTokenSection
                        }
                        
                        // Status & Error Banner
                        if let error = appState.authError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                    .lineLimit(3)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        if !appState.authStatusMessage.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(appState.authStatusMessage)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: 480)
                
                // Footer
                footerLinks
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 660)
    }
    
    private var headerView: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "3370FF"), Color(hex: "1F55E6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color(hex: "3370FF").opacity(0.4), radius: 16, x: 0, y: 8)
                
                Image(systemName: "bird.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Lark Native")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text("极简 · 现代 · 本地原生飞书客户端 (无远程服务器)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var localServerBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.isLocalServerRunning ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(appState.isLocalServerRunning ? "本地回调服务: 运行中 (127.0.0.1:\(appState.localServerPort))" : "本地服务启动中...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                viewModel.copyCallbackUrl(url: configManager.config.redirectUri)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.copiedCallbackToast ? "checkmark" : "doc.on.doc")
                    Text(viewModel.copiedCallbackToast ? "已复制地址" : "复制回调地址")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "3370FF"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private var oauthLoginSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("使用飞书 OAuth 2.0 登录")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("App ID")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("cli_xxxxxxxx", text: $configManager.config.appId)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("App Secret")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                SecureField("输入应用 Secret", text: $configManager.config.appSecret)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("重定向回调 URL (本地监听)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("无需公网服务器")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                TextField("http://127.0.0.1:8989/callback", text: $configManager.config.redirectUri)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }
            
            // Manual code paste toggle
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation {
                        viewModel.showManualCodeInput.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.showManualCodeInput ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                        Text("或直接粘贴回调链接 / 授权 Code")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(hex: "3370FF"))
                }
                .buttonStyle(.plain)
                
                if viewModel.showManualCodeInput {
                    HStack(spacing: 6) {
                        TextField("粘贴 http://127.0.0.1:8989/callback?code=... 或直接粘贴 code", text: $viewModel.manualCodeInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        
                        Button("确认") {
                            Task {
                                await appState.handleIncomingAuthCode(viewModel.manualCodeInput)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(viewModel.manualCodeInput.isEmpty)
                    }
                    .padding(.top, 2)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            HStack {
                if appState.isAuthenticating {
                    Button("取消") {
                        appState.cancelOAuthLogin()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                PrimaryGradientButton(
                    appState.isAuthenticating ? "授权进行中..." : "启动飞书授权登录",
                    icon: "arrow.up.right.square.fill",
                    isLoading: appState.isAuthenticating
                ) {
                    appState.startOAuthLogin()
                }
            }
        }
    }
    
    private var appCredentialsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("通过自建应用获取 Tenant Token")
                .font(.system(size: 13, weight: .semibold))
            
            Text("自建应用免登录模式，直接以应用机器人身份查询已加入的群聊列表。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("App ID")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("cli_xxxxxxxx", text: $configManager.config.appId)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("App Secret")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                SecureField("输入应用 Secret", text: $configManager.config.appSecret)
                    .textFieldStyle(.roundedBorder)
            }
            
            Divider().padding(.vertical, 4)
            
            HStack {
                Spacer()
                PrimaryGradientButton(
                    "使用应用凭据连接",
                    icon: "key.fill",
                    isLoading: appState.isAuthenticating
                ) {
                    Task {
                        await appState.loginWithAppCredentials(
                            appId: configManager.config.appId,
                            appSecret: configManager.config.appSecret
                        )
                    }
                }
            }
        }
    }
    
    private var directTokenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("直接输入 Access Token")
                .font(.system(size: 13, weight: .semibold))
            
            Text("支持直接粘贴通过飞书开放平台调试台生成的 user_access_token 或 tenant_access_token 进行快速体验。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Picker("Token 类型", selection: $viewModel.directTokenType) {
                Text("user_access_token (用户凭证)").tag(UserSession.TokenType.userAccessToken)
                Text("tenant_access_token (企业凭证)").tag(UserSession.TokenType.tenantAccessToken)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Access Token")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.directTokenInput)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 70)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            
            Divider().padding(.vertical, 4)
            
            HStack {
                Spacer()
                PrimaryGradientButton(
                    "验证并登录",
                    icon: "checkmark.shield.fill",
                    isLoading: appState.isAuthenticating
                ) {
                    Task {
                        await appState.loginWithDirectToken(token: viewModel.directTokenInput, tokenType: viewModel.directTokenType)
                    }
                }
            }
        }
    }
    
    private var footerLinks: some View {
        HStack(spacing: 16) {
            Button("飞书开发者后台") {
                if let url = URL(string: "https://open.feishu.cn/app") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
            
            Text("•").foregroundColor(.secondary)
            
            Button("API 调试台") {
                if let url = URL(string: "https://open.feishu.cn/api-explorer") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
            
            Text("•").foregroundColor(.secondary)
            
            Button("查看权限申请指南") {
                if let url = URL(string: "https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/reference/im-v1/chat/list") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            
            RadialGradient(
                colors: [Color(hex: "3370FF").opacity(0.12), Color.clear],
                center: .topLeading,
                startRadius: 50,
                endRadius: 450
            )
            
            RadialGradient(
                colors: [Color(hex: "00B67A").opacity(0.08), Color.clear],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}
