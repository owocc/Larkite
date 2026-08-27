import SwiftUI
import AppKit

@MainActor
public final class ChatDetailViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var copiedField: String? = nil
    
    public init() {}
    
    public func copyToClipboard(text: String, field: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        self.copiedField = field
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.copiedField == field {
                self?.copiedField = nil
            }
        }
    }
}

public struct ChatDetailView: View {
    let chat: FeishuChatItem?
    @StateObject private var viewModel = ChatDetailViewModel()
    
    public init(chat: FeishuChatItem?) {
        self.chat = chat
    }
    
    public var body: some View {
        if let chat = chat {
            VStack(spacing: 0) {
                // Header Bar
                headerBar(chat: chat)
                
                Divider()
                
                // Segment Switcher (Overview vs Raw JSON)
                HStack {
                    Picker("", selection: $viewModel.selectedTab) {
                        Text("群聊概览").tag(0)
                        Text("API JSON 数据").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Content
                if viewModel.selectedTab == 0 {
                    overviewTab(chat: chat)
                } else {
                    rawJsonTab(chat: chat)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            emptySelectionView
        }
    }
    
    private func headerBar(chat: FeishuChatItem) -> some View {
        HStack(spacing: 16) {
            AvatarView(urlString: chat.avatar, name: chat.displayName, size: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(chat.displayName)
                        .font(.system(size: 18, weight: .bold))
                    
                    if chat.isExternal {
                        StatusBadge("外部群", color: Color(hex: "FF9C00"), icon: "globe")
                    } else {
                        StatusBadge("内部群", color: Color(hex: "3370FF"), icon: "lock.shield")
                    }
                    
                    StatusBadge(chat.statusDescription, color: chat.isDissolved ? .red : .green)
                }
                
                Text(chat.description ?? "暂无群介绍")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                viewModel.copyToClipboard(text: chat.chatId, field: "Chat ID")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.copiedField == "Chat ID" ? "checkmark" : "doc.on.doc")
                    Text(viewModel.copiedField == "Chat ID" ? "已复制" : "复制 ID")
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func overviewTab(chat: FeishuChatItem) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Info Grid Card
                GlassCard(cornerRadius: 14, padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("群组详细属性")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        propertyRow(label: "Chat ID", value: chat.chatId, canCopy: true)
                        propertyRow(label: "群名称", value: chat.name ?? "未命名", canCopy: true)
                        propertyRow(label: "群类型", value: chat.isExternal ? "外部群" : "内部群")
                        propertyRow(label: "群状态", value: chat.statusDescription)
                        
                        if let ownerId = chat.ownerId, !ownerId.isEmpty {
                            propertyRow(
                                label: "群主 ID (\(chat.ownerIdType ?? "user_id"))",
                                value: ownerId,
                                canCopy: true
                            )
                        }
                        
                        if let tenantKey = chat.tenantKey, !tenantKey.isEmpty {
                            propertyRow(label: "Tenant Key", value: tenantKey, canCopy: true)
                        }
                        
                        if let desc = chat.description, !desc.isEmpty {
                            propertyRow(label: "群描述", value: desc, canCopy: true)
                        }
                    }
                }
                
                // Placeholder Chat Feed / Mock area for next messaging steps
                GlassCard(cornerRadius: 14, padding: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                                .foregroundColor(Color(hex: "3370FF"))
                            Text("会话消息面板")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("极简预览")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        VStack(spacing: 10) {
                            HStack {
                                Text("💡 已成功接入飞书群组 OpenAPI，群信息已实时加载。可在后续阶段接入群消息实时收发与富文本卡片渲染。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func rawJsonTab(chat: FeishuChatItem) -> some View {
        let jsonString: String = {
            if let data = try? JSONEncoder().encode(chat),
               let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
            return "{}"
        }()
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("飞书 OpenAPI 原始返回载荷")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    viewModel.copyToClipboard(text: jsonString, field: "JSON")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.copiedField == "JSON" ? "checkmark" : "doc.on.doc")
                        Text(viewModel.copiedField == "JSON" ? "已复制" : "复制 JSON")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(hex: "3370FF"))
            }
            .padding(.horizontal, 20)
            
            ScrollView([.horizontal, .vertical]) {
                Text(jsonString)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func propertyRow(label: String, value: String, canCopy: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, design: canCopy ? .monospaced : .default))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            Spacer()
            
            if canCopy {
                Button {
                    viewModel.copyToClipboard(text: value, field: label)
                } label: {
                    Image(systemName: viewModel.copiedField == label ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.copiedField == label ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("复制")
            }
        }
    }
    
    private var emptySelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("选择左侧群聊查看详细信息")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
