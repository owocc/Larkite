import SwiftUI
import AppKit

@MainActor
public final class InAppImageLightboxViewModel: ObservableObject {
    @Published public var scale: CGFloat = 1.0
    @Published public var offset: CGSize = .zero
    @Published public var lastOffset: CGSize = .zero
    @Published public var actionToast: String? = nil
    
    public init() {}
    
    public func resetZoom() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
    
    public func zoomIn() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            scale = min(4.0, scale + 0.3)
        }
    }
    
    public func zoomOut() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            scale = max(0.5, scale - 0.3)
            if scale <= 1.0 {
                offset = .zero
                lastOffset = .zero
            }
        }
    }
    
    public func showToast(_ msg: String) {
        self.actionToast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.actionToast == msg {
                self?.actionToast = nil
            }
        }
    }
}

/// Apple Photos Style In-Detail-Column Image Maximize Viewer (Does not cover sidebar)
public struct InAppImageLightboxView: View {
    let preview: InAppImagePreviewData
    let chatTitle: String
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = InAppImageLightboxViewModel()
    
    public init(preview: InAppImagePreviewData, chatTitle: String = "图片详情") {
        self.preview = preview
        self.chatTitle = chatTitle
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Apple Photos Style Top Header Bar
            applePhotosTopBar
            
            Divider()
            
            // Center Image Stage with Clean Native Window Background
            GeometryReader { geo in
                let maxW = max(100, geo.size.width - 32)
                let maxH = max(100, geo.size.height - 32)
                
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                        .ignoresSafeArea()
                        .onTapGesture {
                            appState.closeInAppImagePreview()
                        }
                    
                    Image(nsImage: preview.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: maxW, maxHeight: maxH)
                        .scaleEffect(viewModel.scale)
                        .offset(viewModel.offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    viewModel.scale = max(0.5, min(4.0, value))
                                }
                                .onEnded { _ in
                                    if viewModel.scale < 1.0 {
                                        viewModel.resetZoom()
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if viewModel.scale > 1.0 {
                                        viewModel.offset = CGSize(
                                            width: viewModel.lastOffset.width + value.translation.width,
                                            height: viewModel.lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if viewModel.scale > 1.0 {
                                        viewModel.lastOffset = viewModel.offset
                                    } else {
                                        viewModel.resetZoom()
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            if viewModel.scale > 1.0 {
                                viewModel.resetZoom()
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    viewModel.scale = 2.0
                                }
                            }
                        }
                    
                    // Floating Bottom Hint & Toast
                    VStack {
                        Spacer()
                        
                        if let toast = viewModel.actionToast {
                            Text(toast)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.8)))
                                .transition(.opacity)
                                .padding(.bottom, 16)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Apple Photos Style Top Header Bar (1:1 Matching Reference Image)
    
    private var applePhotosTopBar: some View {
        HStack(spacing: 12) {
            // Left: Back button + Zoom Slider
            HStack(spacing: 8) {
                Button {
                    appState.closeInAppImagePreview()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .help("返回聊天流 (Esc)")
                
                // Zoom Slider Capsule
                HStack(spacing: 6) {
                    Button {
                        viewModel.zoomOut()
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: $viewModel.scale, in: 0.5...3.0)
                        .frame(width: 80)
                        .controlSize(.mini)
                    
                    Button {
                        viewModel.zoomIn()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
            }
            
            Spacer()
            
            // Center: Image Info / Dimensions
            VStack(spacing: 1) {
                Text(chatTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(Int(preview.image.size.width)) × \(Int(preview.image.size.height)) 像素")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right: Copy, Save, Reset 1:1, Close
            HStack(spacing: 6) {
                // Copy Image
                Button {
                    copyImageToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .help("复制图片到剪贴板")
                
                // Save to Downloads
                Button {
                    saveImageToDownloads()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .help("保存至下载文件夹并在 Finder 中显示")
                
                // Reset 1:1
                Button {
                    viewModel.resetZoom()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .help("还原缩放 (1:1)")
                
                // Close
                Button {
                    appState.closeInAppImagePreview()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .help("关闭查看 (Esc)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func copyImageToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let tiff = preview.image.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
            viewModel.showToast("✓ 已复制图片")
        }
    }
    
    private func saveImageToDownloads() {
        guard let tiffData = preview.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            viewModel.showToast("导出失败")
            return
        }
        
        let downloadsUrl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileUrl = downloadsUrl.appendingPathComponent("飞书图片_\(timestamp).png")
        
        do {
            try pngData.write(to: fileUrl)
            viewModel.showToast("✓ 已保存至下载文件夹")
            NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
        } catch {
            viewModel.showToast("保存失败: \(error.localizedDescription)")
        }
    }
}
