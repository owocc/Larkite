import SwiftUI
import AppKit

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0 // 0: 账号, 1: 外观, 2: 权限
    
    // Credentials drafts
    @Published public var draftAppId: String = ""
    @Published public var draftAppSecret: String = ""
    @Published public var draftRedirectUri: String = "http://127.0.0.1:8989/callback"
    
    // Scopes
    @Published public var scopePreset: Int = 0 // 0: 推荐全能, 1: 纯 IM, 2: 自定义
    @Published public var selectedScopeKeys: Set<String> = Set(FeishuScopes.recommendedList.map(\.key))
    @Published public var showCustomScopes: Bool = false
    
    // Notification & Feedback
    @Published public var autoPlayMedia: Bool = true
    @Published public var playSoundEffects: Bool = true
    @Published public var showSavedToast: Bool = false
    @Published public var copiedCallbackToast: Bool = false
    @Published public var clearedCacheToast: Bool = false
    
    public init() {}
    
    public func initFromConfig(config: AppConfig) {
        self.draftAppId = config.appId
        self.draftAppSecret = config.appSecret
        self.draftRedirectUri = config.redirectUri
        
        let savedScopes = Set(config.scopes.split(separator: " ").map(String.init))
        if !savedScopes.isEmpty {
            self.selectedScopeKeys = savedScopes
        }
    }
    
    public func saveCredentials(configManager: ConfigManager) {
        var cfg = configManager.config
        cfg.appId = draftAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        cfg.appSecret = draftAppSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        cfg.redirectUri = draftRedirectUri.trimmingCharacters(in: .whitespacesAndNewlines)
        cfg.scopes = selectedScopeKeys.sorted().joined(separator: " ")
        configManager.config = cfg
        triggerSavedToast()
    }
    
    public func selectScopePreset(_ preset: Int, configManager: ConfigManager) {
        self.scopePreset = preset
        if preset == 0 {
            self.selectedScopeKeys = Set(FeishuScopes.recommendedList.map(\.key))
            self.showCustomScopes = false
        } else if preset == 1 {
            let minimal = FeishuScopes.recommendedList.filter { $0.isEssential }.map(\.key)
            self.selectedScopeKeys = Set(minimal)
            self.showCustomScopes = false
        } else {
            self.showCustomScopes = true
        }
        saveCredentials(configManager: configManager)
    }
    
    public func toggleScopeKey(_ key: String, configManager: ConfigManager) {
        if selectedScopeKeys.contains(key) {
            selectedScopeKeys.remove(key)
        } else {
            selectedScopeKeys.insert(key)
        }
        saveCredentials(configManager: configManager)
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
    
    public func clearMediaCache() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("LarkNative", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
        
        withAnimation {
            clearedCacheToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation {
                self?.clearedCacheToast = false
            }
        }
    }
    
    public func triggerSavedToast() {
        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation {
                self?.showSavedToast = false
            }
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Centered Native Preferences Tabs (Seamless, Transparent Header)
            topTabBar
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 10)
            
            // Tab Content
            ScrollView {
                VStack(spacing: 18) {
                    if viewModel.selectedTab == 0 {
                        accountsTabContent
                    } else if viewModel.selectedTab == 1 {
                        appearanceTabContent
                    } else {
                        permissionsTabContent
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 560, minHeight: 480, idealHeight: 520, maxHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.initFromConfig(config: configManager.config)
        }
    }
    
    // MARK: - Top Tab Bar (macOS Native Preferences Style)
    
    private var topTabBar: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 8) {
                tabButton(title: "账号", icon: "person.crop.circle", tab: 0)
                tabButton(title: "外观", icon: "paintbrush.fill", tab: 1)
                tabButton(title: "权限", icon: "lock.shield.fill", tab: 2)
            }
            
            Spacer()
        }
        .overlay(alignment: .trailing) {
            if viewModel.showSavedToast {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已保存")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity)
                .padding(.trailing, 12)
            }
        }
    }
    
    private func tabButton(title: String, icon: String, tab: Int) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                viewModel.selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? configManager.accentColorChoice.color : Color(nsColor: .controlBackgroundColor).opacity(0.45))
            )
            .overlay(
                Group {
                    if isSelected {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    } else {
                        Capsule()
                            .strokeBorder(LiquidGlassTheme.specularRimLight, lineWidth: 1)
                    }
                }
            )
            .shadow(color: isSelected ? configManager.accentColorChoice.color.opacity(0.35) : Color.black.opacity(0.04), radius: 4, x: 0, y: 1.5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 0: 账号 (Accounts)
    
    private var accountsTabContent: some View {
        VStack(spacing: 16) {
            // Large Center Profile Avatar & Display Name (matching reference image 071ae68c201a770f.png)
            VStack(spacing: 8) {
                if let user = appState.session?.user {
                    AvatarView(urlString: user.bestAvatarUrl, name: user.displayName, size: 72)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                    
                    Text(user.displayName)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(user.email ?? "飞书已连接账号")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else if let activeId = configManager.activeAccountId, let acc = configManager.accounts.first(where: { $0.id == activeId }) {
                    AvatarView(urlString: acc.avatarUrl, name: acc.displayName, size: 72)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                    
                    Text(acc.displayName)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(acc.email ?? acc.id)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("未登录账号")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding(.vertical, 8)
            
            // Saved Accounts List (1-Click Switch)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("已保存企业组织与账号")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(configManager.accounts.count) 个可用")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                ForEach(configManager.accounts) { acc in
                    let isActive = acc.id == configManager.activeAccountId
                    Button {
                        appState.switchAccount(to: acc.id)
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(urlString: acc.avatarUrl, name: acc.displayName, size: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(acc.displayName)
                                    .font(.system(size: 12, weight: isActive ? .bold : .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(acc.email ?? acc.id)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if isActive {
                                StatusBadge("当前使用", color: .green)
                            }
                        }
                        .padding(8)
                        .background(isActive ? Color(hex: "3370FF").opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("点击直接切换至「\(acc.displayName)」")
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    AccountWindowManager.shared.showLoginWindow()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("登录新企业账号...")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Spacer()
                
                Button(role: .destructive) {
                    appState.logoutCurrentAccount()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("退出当前账号")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
    
    // MARK: - Tab 1: 外观 (Appearance)
    
    private var appearanceTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Theme Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("系统外观模式")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $configManager.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Accent Color
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("强调色")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    StatusBadge(configManager.accentColorChoice.rawValue, color: configManager.accentColorChoice.color)
                }
                HStack(spacing: 10) {
                    ForEach(AccentColorChoice.allCases) { choice in
                        Button {
                            configManager.accentColorChoice = choice
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(choice.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                
                                if configManager.accentColorChoice == choice {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(choice.rawValue)
                    }
                }
            }
            // Live Message Bubble Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("消息气泡外观实时预览")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    // Incoming Grey Bubble
                    HStack {
                        Text("这是对方发送的消息内容，采用 Apple 灰调。")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .padding(.leading, 18)
                            .padding(.trailing, 14)
                            .padding(.vertical, 8)
                            .background(
                                ChatBubbleShape(isSelf: false)
                                    .fill(Color.appleMessagesIncomingBubble)
                            )
                        Spacer()
                    }
                    
                    // Outgoing Accent Bubble
                    HStack {
                        Spacer()
                        Text("这是我发送的消息，采用您选中的主题强调色！")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.leading, 14)
                            .padding(.trailing, 18)
                            .padding(.vertical, 8)
                            .background(
                                ChatBubbleShape(isSelf: true)
                                    .fill(configManager.accentColorChoice.color)
                            )
                    }
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            Divider()
            
            // Notification / Sound Toggles
            VStack(alignment: .leading, spacing: 10) {
                Text("消息与多媒体偏好")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Toggle("自动播放消息音效", isOn: $viewModel.playSoundEffects)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                
                Toggle("启用 macOS 26+ 悬浮液态玻璃交互动效", isOn: $viewModel.autoPlayMedia)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
        }
    }
    
    // MARK: - Tab 2: 权限 (Permissions & OpenAPI)
    
    private var permissionsTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // App ID & Secret
            VStack(alignment: .leading, spacing: 10) {
                Text("自建应用开发者凭据 (App ID & Secret)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("App ID:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                        TextField("cli_xxxxxxxxxxxx", text: $viewModel.draftAppId)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .onChange(of: viewModel.draftAppId) { _, _ in
                                viewModel.saveCredentials(configManager: configManager)
                            }
                    }
                    
                    HStack {
                        Text("App Secret:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                        SecureField("输入 App Secret", text: $viewModel.draftAppSecret)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .onChange(of: viewModel.draftAppSecret) { _, _ in
                                viewModel.saveCredentials(configManager: configManager)
                            }
                    }
                }
            }
            
            Divider()
            
            // Callback URI with 1-Click Copy
            VStack(alignment: .leading, spacing: 8) {
                Text("OAuth 本地回调地址")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(viewModel.draftRedirectUri)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        viewModel.copyCallbackUrl(url: viewModel.draftRedirectUri)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: viewModel.copiedCallbackToast ? "checkmark" : "doc.on.doc")
                            Text(viewModel.copiedCallbackToast ? "已复制" : "复制回调地址")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            Divider()
            
            // Scopes Configuration
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("OpenAPI 授权权限 (Scopes)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.selectedScopeKeys.count) 项已选")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Picker("", selection: $viewModel.scopePreset) {
                    Text("推荐全能权限").tag(0)
                    Text("极简 IM 消息").tag(1)
                    Text("自定义勾选").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.scopePreset) { _, newPreset in
                    viewModel.selectScopePreset(newPreset, configManager: configManager)
                }
                
                if viewModel.showCustomScopes {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(FeishuScopes.recommendedList) { scope in
                                Toggle(isOn: Binding(
                                    get: { viewModel.selectedScopeKeys.contains(scope.key) },
                                    set: { _ in viewModel.toggleScopeKey(scope.key, configManager: configManager) }
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
                    .frame(maxHeight: 140)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            Divider()
            
            // Cache Management
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地缓存与临时文件")
                        .font(.system(size: 12, weight: .medium))
                    Text("清理已下载的图片、视频与文件临时缓存")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    viewModel.clearMediaCache()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.clearedCacheToast ? "checkmark" : "trash")
                        Text(viewModel.clearedCacheToast ? "已清理" : "清除缓存")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
