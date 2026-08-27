import SwiftUI
import AppKit

@MainActor
public final class MessageMediaViewModel: ObservableObject {
    @Published public var isPreviewing: Bool = false
    @Published public var isDownloading: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var actionToast: String? = nil
    
    public init() {}
    
    public func previewMedia(messageId: String, fileKey: String, fileName: String?) {
        let token = AppState.shared.session?.accessToken ?? ""
        guard !token.isEmpty else { return }
        
        isPreviewing = true
        Task {
            do {
                try await MessageResourceManager.shared.previewMedia(
                    token: token,
                    messageId: messageId,
                    fileKey: fileKey,
                    fileName: fileName
                )
                self.isPreviewing = false
            } catch {
                self.isPreviewing = false
                showToast("打开播放器失败: \(error.localizedDescription)")
            }
        }
    }
    
    public func downloadMedia(messageId: String, fileKey: String, fileName: String?) {
        let token = AppState.shared.session?.accessToken ?? ""
        guard !token.isEmpty else { return }
        
        isDownloading = true
        Task {
            do {
                _ = try await MessageResourceManager.shared.downloadAndSaveMedia(
                    token: token,
                    messageId: messageId,
                    fileKey: fileKey,
                    fileName: fileName
                )
                self.isDownloading = false
                showToast("✓ 已保存至下载目录并在 Finder 中显示")
            } catch {
                self.isDownloading = false
                showToast("下载失败: \(error.localizedDescription)")
            }
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

public struct MessageMediaView: View {
    let messageId: String
    let fileKey: String
    let imageKey: String?
    let fileName: String?
    let durationSec: Int?
    
    @StateObject private var viewModel = MessageMediaViewModel()
    
    public init(
        messageId: String,
        fileKey: String,
        imageKey: String?,
        fileName: String?,
        durationSec: Int?
    ) {
        self.messageId = messageId
        self.fileKey = fileKey
        self.imageKey = imageKey
        self.fileName = fileName
        self.durationSec = durationSec
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Video Thumbnail & Player Card
            ZStack(alignment: .center) {
                if let imgKey = imageKey, !imgKey.isEmpty {
                    MessageImageView(messageId: messageId, imageKey: imgKey)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        .frame(width: 240, height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.8)
                        )
                }
                
                // Centered Play Button Overlay
                Button {
                    viewModel.previewMedia(messageId: messageId, fileKey: fileKey, fileName: fileName)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 44, height: 44)
                        if viewModel.isPreviewing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("调用 macOS 默认播放器预览 (QuickTime Player)")
                
                // Duration Badge (Bottom-Left)
                if let sec = durationSec {
                    VStack {
                        Spacer()
                        HStack {
                            Text(formatDuration(seconds: sec))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.75))
                                .clipShape(Capsule())
                                .padding(8)
                            Spacer()
                        }
                    }
                }
                
                // Top-Right Hover Action Toolbar (Telegram macOS Style)
                if viewModel.isHovered {
                    VStack {
                        HStack {
                            Spacer()
                            hoverMediaToolbar
                                .transition(.opacity)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.isHovered = hovering
                }
            }
            .contextMenu {
                Button {
                    viewModel.previewMedia(messageId: messageId, fileKey: fileKey, fileName: fileName)
                } label: {
                    Label("在 QuickTime 中打开预览", systemImage: "play.fill")
                }
                
                Button {
                    viewModel.downloadMedia(messageId: messageId, fileKey: fileKey, fileName: fileName)
                } label: {
                    Label("保存到下载目录并在 Finder 显示", systemImage: "arrow.down.circle.fill")
                }
            }
            
            if let toast = viewModel.actionToast {
                Text(toast)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "3370FF"))
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private var hoverMediaToolbar: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.previewMedia(messageId: messageId, fileKey: fileKey, fileName: fileName)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("在 QuickTime 中播放")
            
            Button {
                viewModel.downloadMedia(messageId: messageId, fileKey: fileKey, fileName: fileName)
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("保存至下载并在 Finder 中显示")
        }
    }
    
    private func formatDuration(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
