import SwiftUI
import AppKit

@MainActor
public final class MessageImageViewModel: ObservableObject {
    @Published public var image: NSImage?
    @Published public var isLoading: Bool = false
    @Published public var loadFailed: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var actionToast: String? = nil
    
    private var hasAttempted: Bool = false
    
    public init() {}
    
    public func loadImage(messageId: String, imageKey: String) {
        guard !imageKey.isEmpty, !hasAttempted else { return }
        
        let token = AppState.shared.session?.accessToken ?? ""
        guard !token.isEmpty else { return }
        
        let cacheKey = "\(messageId)_\(imageKey)"
        if let cached = MessageResourceManager.shared.getCachedImage(key: cacheKey) {
            self.image = cached
            self.hasAttempted = true
            return
        }
        
        hasAttempted = true
        isLoading = true
        loadFailed = false
        
        Task {
            if let loaded = await MessageResourceManager.shared.loadImage(
                token: token,
                messageId: messageId,
                fileKey: imageKey
            ) {
                self.image = loaded
                self.isLoading = false
            } else {
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }
    
    public func retry(messageId: String, imageKey: String) {
        hasAttempted = false
        loadImage(messageId: messageId, imageKey: imageKey)
    }
    
    public func previewInSystem(messageId: String, imageKey: String) {
        let token = AppState.shared.session?.accessToken ?? ""
        guard !token.isEmpty else { return }
        
        Task {
            do {
                try await MessageResourceManager.shared.previewImage(
                    token: token,
                    messageId: messageId,
                    imageKey: imageKey
                )
            } catch {
                showToast("打开预览失败: \(error.localizedDescription)")
            }
        }
    }
    
    public func downloadImage(messageId: String, imageKey: String) {
        let token = AppState.shared.session?.accessToken ?? ""
        guard !token.isEmpty else { return }
        
        Task {
            do {
                _ = try await MessageResourceManager.shared.downloadAndSaveImage(
                    token: token,
                    messageId: messageId,
                    imageKey: imageKey
                )
                showToast("✓ 已保存至下载目录并在 Finder 中显示")
            } catch {
                showToast("下载失败: \(error.localizedDescription)")
            }
        }
    }
    
    public func copyImageToClipboard() {
        guard let img = image else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let tiff = img.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
            showToast("已复制图片到剪贴板")
        }
    }
    
    private func showToast(_ msg: String) {
        self.actionToast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.actionToast == msg {
                self?.actionToast = nil
            }
        }
    }
}

public struct MessageImageView: View {
    let messageId: String
    let imageKey: String
    
    @StateObject private var viewModel = MessageImageViewModel()
    
    public init(messageId: String, imageKey: String) {
        self.messageId = messageId
        self.imageKey = imageKey
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let img = viewModel.image {
                    let size = calculateDisplaySize(for: img)
                    
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.8)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.previewInSystem(messageId: messageId, imageKey: imageKey)
                            }
                        
                        if viewModel.isHovered {
                            hoverToolbar
                                .transition(.opacity)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.isHovered = hovering
                        }
                    }
                } else if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在加载图片...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if viewModel.loadFailed {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("图片未包含或无法下载")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Button("重试") {
                            viewModel.retry(messageId: messageId, imageKey: imageKey)
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }
                    .padding(12)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Color.clear
                        .frame(width: 80, height: 40)
                        .onAppear {
                            viewModel.loadImage(messageId: messageId, imageKey: imageKey)
                        }
                }
            }
            
            if let toast = viewModel.actionToast {
                Text(toast)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "3370FF"))
                    .transition(.opacity)
            }
        }
        .onAppear {
            viewModel.loadImage(messageId: messageId, imageKey: imageKey)
        }
    }
    private func calculateDisplaySize(for img: NSImage) -> CGSize {
        let originalWidth = max(1, img.size.width)
        let originalHeight = max(1, img.size.height)
        let maxWidth: CGFloat = 300
        let maxHeight: CGFloat = 360
        let minWidth: CGFloat = 80
        let minHeight: CGFloat = 60
        
        let widthRatio = maxWidth / originalWidth
        let heightRatio = maxHeight / originalHeight
        let scale = min(1.0, min(widthRatio, heightRatio))
        
        let targetWidth = max(minWidth, min(maxWidth, originalWidth * scale))
        let targetHeight = max(minHeight, min(maxHeight, originalHeight * scale))
        
        return CGSize(width: targetWidth, height: targetHeight)
    }
    
    private var hoverToolbar: some View {
        HStack(spacing: 4) {
            // Preview in system default
            Button {
                viewModel.previewInSystem(messageId: messageId, imageKey: imageKey)
            } label: {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("系统默认预览 (Preview.app)")
            
            // Download to disk
            Button {
                viewModel.downloadImage(messageId: messageId, imageKey: imageKey)
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("保存至下载目录并在 Finder 显示")
            
            // Copy
            Button {
                viewModel.copyImageToClipboard()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("复制图片")
        }
        .padding(6)
    }
}
