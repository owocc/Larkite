import SwiftUI
import AppKit

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var showProfileSheet: Bool = false
    @Published public var showDirectTokenSheet: Bool = false
    @Published public var showScopesSheet: Bool = false
    @Published public var showAccountPopover: Bool = false
    @Published public var showServerPopover: Bool = false
    @Published public var draftAppId: String = ""
    @Published public var draftAppSecret: String = ""
    @Published public var draftRedirectUri: String = "http://127.0.0.1:8989/callback"
    
    // Direct Token Input
    @Published public var directTokenInput: String = ""
    @Published public var directTokenType: UserSession.TokenType = .userAccessToken
    
    // Scopes
    @Published public var scopePreset: Int = 0 // 0: 推荐全能, 1: 纯 IM 极简, 2: 自定义
    @Published public var selectedScopeKeys: Set<String> = Set(FeishuScopes.recommendedList.map(\.key))
    
    // Feedback
    @Published public var copiedCallbackToast: Bool = false
    
    public init() {}
    
    public func initDrafts(config: AppConfig) {
        if draftAppId.isEmpty && !config.appId.isEmpty {
            draftAppId = config.appId
            draftAppSecret = config.appSecret
            draftRedirectUri = config.redirectUri
        }
    }
    
    public func buildDraftConfig() -> AppConfig {
        AppConfig(
            appId: draftAppId.trimmingCharacters(in: .whitespacesAndNewlines),
            appSecret: draftAppSecret.trimmingCharacters(in: .whitespacesAndNewlines),
            redirectUri: draftRedirectUri.trimmingCharacters(in: .whitespacesAndNewlines),
            scopes: selectedScopeKeys.sorted().joined(separator: " "),
            port: 8989
        )
    }
    
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
    
    public func selectPreset(_ preset: Int) {
        self.scopePreset = preset
        if preset == 0 {
            self.selectedScopeKeys = Set(FeishuScopes.recommendedList.map(\.key))
        } else if preset == 1 {
            let minimal = FeishuScopes.recommendedList.filter { $0.isEssential }.map(\.key)
            self.selectedScopeKeys = Set(minimal)
        }
    }
    
    public func toggleScopeKey(_ key: String) {
        if selectedScopeKeys.contains(key) {
            selectedScopeKeys.remove(key)
        } else {
            selectedScopeKeys.insert(key)
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
            
            VStack(spacing: 0) {
                // Top Header: Action Group right at the top-right corner
                topHeaderSection
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                Spacer(minLength: 0)
                
                // Main Login Body (Brand + 3 Buttons)
                mainContentSection
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 0)
                
                // Bottom Callback Info & Status Bar
                bottomCallbackSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }
        }
        .frame(minWidth: 480, idealWidth: 500, maxWidth: 540, minHeight: 360, idealHeight: 375, maxHeight: 400)
        .onAppear {
            viewModel.initDrafts(config: configManager.config)
        }
        .sheet(isPresented: $viewModel.showProfileSheet) {
            appProfileConfigSheet
        }
        .sheet(isPresented: $viewModel.showDirectTokenSheet) {
            directTokenInputSheet
        }
        .sheet(isPresented: $viewModel.showScopesSheet) {
            scopeSettingsSheet
        }
    }
    
    // MARK: - Top Header Section (Liquid Glass, No Extra Chevrons)
    
    private var topHeaderSection: some View {
        HStack(spacing: 8) {
            // Left spacer for native traffic lights
            Spacer()
            
            // Right 1: User / Saved Accounts Switcher Circular Liquid Glass Button (matching sidebar style)
            Button {
                viewModel.showAccountPopover.toggle()
            } label: {
                Image(systemName: configManager.activeAccountId != nil ? "person.crop.circle.fill" : "person.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(configManager.activeAccountId != nil ? Color(hex: "3370FF") : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        ZStack {
                            VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                            Color(nsColor: .controlBackgroundColor).opacity(0.55)
                        }
                        .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .help("切换企业组织与已保存账号")
            .popover(isPresented: $viewModel.showAccountPopover, arrowEdge: .bottom) {
                accountSwitcherPopoverView
            }
            
            // Right 2: Server / App Profile Circular Liquid Glass Button (matching sidebar style)
            Button {
                viewModel.showServerPopover.toggle()
            } label: {
                Image(systemName: "server.rack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        ZStack {
                            VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                            Color(nsColor: .controlBackgroundColor).opacity(0.55)
                        }
                        .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .help("自建应用与服务配置 (Server Profile)")
            .popover(isPresented: $viewModel.showServerPopover, arrowEdge: .bottom) {
                serverConfigPopoverView
            }
        }
    }
    
    // MARK: - Account Switcher Popover View
    
    private var accountSwitcherPopoverView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已保存企业账号")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(configManager.accounts.count) 个可用")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            if configManager.accounts.isEmpty {
                Text("暂无已保存账号，请在下方选择方式登录")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(configManager.accounts) { acc in
                            let isActive = acc.id == configManager.activeAccountId
                            Button {
                                appState.switchAccount(to: acc.id)
                                viewModel.showAccountPopover = false
                                AccountWindowManager.shared.closeWindow()
                            } label: {
                                HStack(spacing: 8) {
                                    AvatarView(urlString: acc.avatarUrl, name: acc.displayName, size: 26)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acc.displayName)
                                            .font(.system(size: 11, weight: isActive ? .bold : .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(acc.email ?? acc.id)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if isActive {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isActive ? Color(hex: "3370FF").opacity(0.12) : Color(nsColor: .quaternaryLabelColor).opacity(0.1))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("点击直接切换至「\(acc.displayName)」")
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
            
            Divider()
            
            Button {
                viewModel.showAccountPopover = false
                appState.startAddingNewAccount()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("登录新账号 / 添加新企业")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "3370FF"))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 250)
    }
    
    // MARK: - Server Config Popover View
    
    private var serverConfigPopoverView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.showServerPopover = false
                viewModel.showProfileSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("配置自建应用凭据 (App ID / Secret)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button {
                viewModel.showServerPopover = false
                viewModel.showScopesSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("设置 OpenAPI 授权权限 (Scopes)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button {
                viewModel.showServerPopover = false
                viewModel.copyCallbackUrl(url: viewModel.draftRedirectUri)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                    Text("复制本地回调地址 (8989)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 260)
    }
    
    // MARK: - Main Login Body (3 Clean Action Buttons)
    
    private var mainContentSection: some View {
        VStack(spacing: 16) {
            // Brand Logo & Title
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "3370FF"))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "bird.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lark Native")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("极简原生飞书 / Lark 客户端")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)
            
            // 3 Clean Primary Login Buttons
            VStack(spacing: 10) {
                // Button 1: OAuth 2.0 Web Login (Primary Action)
                Button {
                    let cfg = viewModel.buildDraftConfig()
                    configManager.config = cfg
                    appState.startOAuthLogin()
                } label: {
                    HStack(spacing: 8) {
                        if appState.isAuthenticating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("飞书网页一键授权登录 (OAuth 2.0)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color(hex: "3370FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(appState.isAuthenticating)
                .help("在默认浏览器中打开飞书授权页面，自动捕获凭据")
                
                // Button 2: Tenant Access Token (Bot / App Mode)
                Button {
                    let cfg = viewModel.buildDraftConfig()
                    configManager.config = cfg
                    Task {
                        await appState.loginWithAppCredentials(appId: cfg.appId, appSecret: cfg.appSecret)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 12))
                        Text("自建应用机器人模式进入 (Tenant Token)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.isAuthenticating)
                .help("使用 App ID 和 App Secret 直接获取 tenant_access_token 免登录进入")
                // Button 3: Direct User Access Token Input
                Button {
                    viewModel.showDirectTokenSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                        Text("录入 User Access Token 访问凭据...")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("手动粘贴 user_access_token (u-xxxx) 或 tenant_access_token (t-xxxx)")
            }
            .frame(maxWidth: 380)
            
            // Status & Error Toast
            if let error = appState.authError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if !appState.authStatusMessage.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(appState.authStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
    
    // MARK: - Bottom Callback Info Bar with 1-Click Copy
    
    private var bottomCallbackSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "network")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text("本地回调: \(viewModel.draftRedirectUri)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            Button {
                viewModel.copyCallbackUrl(url: viewModel.draftRedirectUri)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: viewModel.copiedCallbackToast ? "checkmark" : "doc.on.doc")
                    Text(viewModel.copiedCallbackToast ? "已复制" : "复制")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(viewModel.copiedCallbackToast ? .green : Color(hex: "3370FF"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "3370FF").opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("一键复制回调地址并在飞书开放平台配置")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - App Profile / Server Configuration Sheet
    
    private var appProfileConfigSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("自建应用与服务配置 (Profile)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("完成") {
                    let cfg = viewModel.buildDraftConfig()
                    configManager.config = cfg
                    viewModel.showProfileSheet = false
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App ID")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("cli_xxxxxxxxxxxx", text: $viewModel.draftAppId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Secret")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    SecureField("输入 App Secret", text: $viewModel.draftAppSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("OAuth 重定向地址")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("http://127.0.0.1:8989/callback", text: $viewModel.draftRedirectUri)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
                
                Spacer()
            }
            .padding(16)
        }
        .frame(width: 440, height: 320)
    }
    
    // MARK: - Direct Token Input Sheet
    
    private var directTokenInputSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("录入访问凭证 (Direct Token)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("关闭") {
                    viewModel.showDirectTokenSheet = false
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 14) {
                Picker("凭证类型", selection: $viewModel.directTokenType) {
                    Text("User Access Token (u-xxxx)").tag(UserSession.TokenType.userAccessToken)
                    Text("Tenant Access Token (t-xxxx)").tag(UserSession.TokenType.tenantAccessToken)
                }
                .pickerStyle(.segmented)
                
                TextEditor(text: $viewModel.directTokenInput)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 100)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.8)
                    )
                
                Button {
                    let clean = viewModel.directTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    viewModel.showDirectTokenSheet = false
                    Task {
                        await appState.loginWithDirectToken(token: clean, tokenType: viewModel.directTokenType)
                    }
                } label: {
                    Text("确认登录并连接")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.directTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding(16)
        }
        .frame(width: 440, height: 300)
    }
    
    // MARK: - Scopes Setting Sheet
    
    private var scopeSettingsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("OpenAPI 授权权限 (Scopes)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("完成") {
                    viewModel.showScopesSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $viewModel.scopePreset) {
                    Text("推荐全能权限").tag(0)
                    Text("极简 IM 消息权限").tag(1)
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.scopePreset) { _, newPreset in
                    viewModel.selectPreset(newPreset)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(FeishuScopes.recommendedList) { scope in
                            Toggle(isOn: Binding(
                                get: { viewModel.selectedScopeKeys.contains(scope.key) },
                                set: { _ in viewModel.toggleScopeKey(scope.key) }
                            )) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(scope.name)
                                        .font(.system(size: 11, weight: .medium))
                                    Text(scope.key)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 200)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
        }
        .frame(width: 440, height: 340)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(hex: "3370FF").opacity(0.04),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

