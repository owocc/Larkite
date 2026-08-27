import SwiftUI
import AppKit

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var showSavedToast: Bool = false
    @Published public var copiedScopeKeyToast: Bool = false
    
    public init() {}
    
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
    
    public func copyAllScopes(scopes: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(scopes, forType: .string)
        
        withAnimation {
            copiedScopeKeyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation {
                self?.copiedScopeKeyToast = false
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
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("应用与权限设置")
                            .font(.system(size: 20, weight: .bold))
                        Text("配置飞书 OpenAPI 应用凭证与完整的 Scope 权限清单")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if viewModel.showSavedToast {
                        Text("✓ 已保存")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, 4)
                
                // Active Session Info Card
                if let session = appState.session {
                    sessionInfoCard(session: session)
                }
                
                // Developer Credentials Card
                credentialsCard
                
                // Comprehensive Scope Checklist Card
                scopeChecklistCard
                
                // Documentation Links
                docLinksCard
                
                // Destructive Actions
                HStack {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("清除凭证并退出登录")
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func sessionInfoCard(session: UserSession) -> some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundColor(.green)
                    Text("当前登录会话")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    StatusBadge(session.tokenType.rawValue, color: Color(hex: "3370FF"))
                }
                
                Divider()
                
                if let user = session.user {
                    HStack(spacing: 12) {
                        AvatarView(urlString: user.bestAvatarUrl, name: user.displayName, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.system(size: 13, weight: .medium))
                            Text(user.email ?? user.mobile ?? user.openId ?? "")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack {
                    Text("Access Token")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text(session.accessToken.prefix(20) + "..." + session.accessToken.suffix(8))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                if let expiresAt = session.expiresAt {
                    HStack {
                        Text("有效期至")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Text(expiresAt.formatted(date: .abbreviated, time: .standard))
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private var credentialsCard: some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("飞书开发者凭证配置")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Spacer()
                    
                    StatusBadge("当前账号独立凭据沙箱", color: .green, icon: "lock.shield.fill")
                }
                
                Text("提示：此凭据配置独立绑定至当前账号 / 组织，切换账号时将自动加载对应组织的应用密钥。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("App ID (应用唯一标识)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("cli_xxxxxxxx", text: $configManager.config.appId)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("App Secret (应用密钥)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    SecureField("Secret", text: $configManager.config.appSecret)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("OAuth 重定向地址 (Redirect URI)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("http://127.0.0.1:8989/callback", text: $configManager.config.redirectUri)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Spacer()
                    Button("保存凭证") {
                        configManager.saveConfig()
                        viewModel.triggerSavedToast()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
        }
    }
    
    private var scopeChecklistCard: some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("OAuth 申请 Scope 权限配置")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Spacer()
                    
                    Button {
                        viewModel.copyAllScopes(scopes: configManager.config.scopes)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.copiedScopeKeyToast ? "checkmark" : "doc.on.doc")
                            Text(viewModel.copiedScopeKeyToast ? "已复制 Scope" : "复制全部 Scope Key")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "3370FF"))
                    
                    Button("一键重置为推荐权限") {
                        configManager.resetToRecommendedScopes()
                        viewModel.triggerSavedToast()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前请求的 Scopes (以空格分隔)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $configManager.config.scopes)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 55)
                        .padding(4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }
                
                // Categorized Scope List
                VStack(alignment: .leading, spacing: 12) {
                    Text("推荐权限分类速查 (可在飞书开放平台后台勾选)：")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(FeishuScopeCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• \(category.rawValue)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "3370FF"))
                            
                            let categoryScopes = FeishuScopes.recommendedList.filter { $0.category == category }
                            ForEach(categoryScopes) { scope in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(scope.key)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    
                                    Text(scope.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(scope.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                                .padding(.leading, 12)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Re-auth reminder banner
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color(hex: "3370FF"))
                    Text("💡 提示：在飞书开发者后台新增权限并保存上方 Scope 后，请退出登录并点击「重新授权登录」，飞书才会下发包含新权限的最新 Access Token。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var docLinksCard: some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("官方开发文档快速入口")
                    .font(.system(size: 13, weight: .semibold))
                
                Divider()
                
                docLinkRow(
                    title: "网页应用登录流程概述",
                    subtitle: "OAuth 2.0 授权码机制与 Token 交换说明",
                    url: "https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/reference/authen-v1/login-overview"
                )
                
                docLinkRow(
                    title: "获取会话历史消息",
                    subtitle: "im/v1/messages 接口规范与参数说明",
                    url: "https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/reference/im-v1/message/list"
                )
                
                docLinkRow(
                    title: "获取用户或机器人所在的群列表",
                    subtitle: "im/v1/chats 接口规范与参数说明",
                    url: "https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/reference/im-v1/chat/list"
                )
                
                docLinkRow(
                    title: "获取消息中的资源文件",
                    subtitle: "im/v1/messages/:id/resources/:key 图片与文件下载",
                    url: "https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/reference/im-v1/message-resource/get"
                )
                
                docLinkRow(
                    title: "飞书开放平台开发者后台",
                    subtitle: "创建应用、添加机器人能力与配置重定向 URL",
                    url: "https://open.feishu.cn/app"
                )
            }
        }
    }
    
    private func docLinkRow(title: String, subtitle: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "3370FF"))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
