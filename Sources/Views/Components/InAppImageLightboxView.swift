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
            scale = min(5.0, scale + 0.5)
        }
    }
    
    public func zoomOut() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            scale = max(0.5, scale - 0.5)
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

public struct InAppImageLightboxView: View {
    let preview: InAppImagePreviewData
    
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    @StateObject private var viewModel = InAppImageLightboxViewModel()
    
    public init(preview: InAppImagePreviewData) {
        self.preview = preview
    }
    
    public var body: some View {
        ZStack {
            // Dark Translucent Glass Backdrop (Click to dismiss)
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.closeInAppImagePreview()
                }
            
            // Centered High-Res Image with Pinch & Pan
            GeometryReader { geo in
                let maxW = max(100, geo.size.width - 80)
                let maxH = max(100, geo.size.height - 100)
                
                ZStack {
                    Image(nsImage: preview.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: maxW, maxHeight: maxH)
                        .scaleEffect(viewModel.scale)
                        .offset(viewModel.offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    viewModel.scale = max(0.5, min(5.0, value))
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
                        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 10)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            
            // Floating Top Toolbar
            VStack {
                topToolbarView
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Bottom hint & toast
                HStack(spacing: 8) {
                    if let toast = viewModel.actionToast {
                        Text(toast)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.75)))
                            .transition(.opacity)
                    } else {
                        Text("双击缩放 • 点击背景或按 Esc 退出")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.4)))
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Floating Top Toolbar
    
    private var topToolbarView: some View {
        HStack(spacing: 12) {
            // Resolution Badge
            HStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 11))
                Text("\(Int(preview.image.size.width)) × \(Int(preview.image.size.height))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
            )
            
            Spacer()
            
            // Action Buttons Pill
            HStack(spacing: 4) {
                // Zoom Out
                Button {
                    viewModel.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("缩小")
                
                // Zoom In
                Button {
                    viewModel.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("放大")
                
                // Reset Zoom (1:1)
                Button {
                    viewModel.resetZoom()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("还原原始尺寸")
                
                Divider()
                    .frame(height: 14)
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 2)
                
                // Copy Image
                Button {
                    copyImageToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("复制图片到剪贴板")
                
                // Save Image to Downloads
                Button {
                    saveImageToDownloads()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("保存至下载文件夹并在 Finder 中显示")
                
                Divider()
                    .frame(height: 14)
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 2)
                
                // Close Lightbox Button
                Button {
                    appState.closeInAppImagePreview()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("关闭预览 (Esc)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        }
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
