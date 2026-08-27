import SwiftUI
import AppKit

@MainActor
public final class MessageImageViewModel: ObservableObject {
    @Published public var image: NSImage?
    @Published public var isLoading: Bool = false
    @Published public var loadFailed: Bool = false
    @Published public var isHovered: Bool = false
    
    public init() {}
    
    public func loadImage(messageId: String, imageKey: String) {
        guard !imageKey.isEmpty else { return }
        
        let token = AppState.shared.session?.accessToken ?? ""
        guard !token.isEmpty else { return }
        
        if let cached = MessageResourceManager.shared.getCachedImage(key: "\(messageId)_\(imageKey)") {
            self.image = cached
            return
        }
        
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
    
    public func copyImageToClipboard() {
        guard let img = image else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let tiff = img.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
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
        Group {
            if let img = viewModel.image {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    
                    if viewModel.isHovered {
                        HStack(spacing: 4) {
                            Button {
                                viewModel.copyImageToClipboard()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("复制图片")
                        }
                        .padding(6)
                    }
                }
                .onHover { hovering in
                    viewModel.isHovered = hovering
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
                    Text("图片加载失败 (\(imageKey.prefix(8))...)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Button("重试") {
                        viewModel.loadImage(messageId: messageId, imageKey: imageKey)
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
        .onAppear {
            viewModel.loadImage(messageId: messageId, imageKey: imageKey)
        }
    }
}
