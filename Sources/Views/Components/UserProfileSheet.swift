import SwiftUI
import AppKit

@MainActor
public final class UserProfileSheetViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0 // 0: 详细资料, 1: 原始 API JSON
    @Published public var copiedToast: String? = nil
    
    public init() {}
    
    public func copyToClipboard(text: String, label: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        self.copiedToast = "\(label)已复制"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.copiedToast == "\(label)已复制" {
                self?.copiedToast = nil
            }
        }
    }
}

public struct UserProfileSheet: View {
    let user: DetailedFeishuUser
    @ObservedObject var appState: AppState = .shared
    @StateObject private var viewModel = UserProfileSheetViewModel()
    
    public init(user: DetailedFeishuUser) {
        self.user = user
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(20)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Tab Switcher
            HStack {
                Picker("", selection: $viewModel.selectedTab) {
                    Text("用户完整画像").tag(0)
                    Text("API 原始 JSON 载荷").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                
                Spacer()
                
                if let toast = viewModel.copiedToast {
                    Text(toast)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            // Body Content
            if viewModel.selectedTab == 0 {
                detailedAttributesView
            } else {
                rawJsonPayloadView
            }
        }
        .frame(width: 520, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            AvatarView(
                urlString: user.bestAvatarUrl,
                name: user.displayName,
                size: 60
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.system(size: 18, weight: .bold))
                    
                    if user.isTenantManager == true {
                        StatusBadge("企业超管", color: Color(hex: "7838FF"), icon: "shield.fill")
                    }
                    
                    if let statusDesc = user.status?.description {
                        StatusBadge(statusDesc, color: user.status?.isResigned == true ? .red : .green)
                    }
                }
                
                if let job = user.jobTitle {
                    Text(job)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                if let dept = user.departmentSummary {
                    Text(dept)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "3370FF"))
                }
            }
            
            Spacer()
            
            // Quick Chat Button
            if let openId = user.openId {
                PrimaryGradientButton("发消息", icon: "bubble.left.and.bubble.right.fill") {
                    Task {
                        try? await appState.openDirectChatWithUser(idType: "open_id", idValue: openId)
                        appState.inspectedUser = nil
                    }
                }
            }
        }
    }
    
    private var detailedAttributesView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 基本信息卡片
                GlassCard(cornerRadius: 12, padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(title: "基本资料", icon: "person.fill")
                        
                        Divider()
                        
                        propertyRow(label: "中文姓名", value: user.name)
                        propertyRow(label: "英文姓名", value: user.enName)
                        propertyRow(label: "花名 / 昵称", value: user.nickname)
                        propertyRow(label: "性别", value: user.genderDescription)
                        propertyRow(label: "手机号码", value: user.mobile, canCopy: true)
                        propertyRow(label: "企业邮箱", value: user.enterpriseEmail, canCopy: true)
                        propertyRow(label: "个人邮箱", value: user.email, canCopy: true)
                    }
                }
                
                // 工作与组织架构卡片
                GlassCard(cornerRadius: 12, padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(title: "工作与组织架构", icon: "building.2.fill")
                        
                        Divider()
                        
                        propertyRow(label: "员工类型", value: user.employeeTypeDescription)
                        propertyRow(label: "工号", value: user.employeeNo, canCopy: true)
                        propertyRow(label: "职务 / 岗位", value: user.jobTitle)
                        propertyRow(label: "所属部门路径", value: user.departmentSummary)
                        propertyRow(label: "工作城市", value: user.city)
                        propertyRow(label: "工位 / 座位", value: user.workStation)
                        propertyRow(label: "入职时间", value: user.formattedJoinTime)
                        propertyRow(label: "直属主管 ID", value: user.leaderUserId, canCopy: true)
                    }
                }
                
                // 系统标识与权限
                GlassCard(cornerRadius: 12, padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(title: "系统标识与权限", icon: "key.fill")
                        
                        Divider()
                        
                        propertyRow(label: "User Open ID", value: user.openId, canCopy: true)
                        propertyRow(label: "User ID", value: user.userId, canCopy: true)
                        propertyRow(label: "Union ID", value: user.unionId, canCopy: true)
                        propertyRow(label: "数据驻留地 (Geo)", value: user.geo)
                        propertyRow(label: "职级 ID", value: user.jobLevelId)
                        propertyRow(label: "序列 ID", value: user.jobFamilyId)
                    }
                }
            }
            .padding(16)
        }
    }
    
    private var rawJsonPayloadView: some View {
        let jsonString: String = {
            if let raw = user.rawJsonString, !raw.isEmpty {
                return raw
            }
            if let data = try? JSONEncoder().encode(user),
               let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let str = String(data: pretty, encoding: .utf8) {
                return str
            }
            return "{}"
        }()
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("飞书 OpenAPI contact/v3/users 返回的全部字段")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    viewModel.copyToClipboard(text: jsonString, label: "JSON 载荷")
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("复制完整 JSON")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(hex: "3370FF"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            ScrollView([.horizontal, .vertical]) {
                Text(jsonString)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .padding(16)
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "3370FF"))
                .font(.system(size: 12))
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func propertyRow(label: String, value: String?, canCopy: Bool = false) -> some View {
        if let val = value, !val.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                
                Text(val)
                    .font(.system(size: 11, design: canCopy ? .monospaced : .default))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
                
                if canCopy {
                    Button {
                        viewModel.copyToClipboard(text: val, label: label)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("复制 \(label)")
                }
            }
            .padding(.vertical, 1)
        }
    }
}
