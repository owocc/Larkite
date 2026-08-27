import SwiftUI
import AppKit

@MainActor
public final class MessageFileViewModel: ObservableObject {
    @Published public var isDownloading: Bool = false
    @Published public var downloadedUrl: URL?
    @Published public var downloadError: String?
    
    public init() {}
    
    public func downloadFile(messageId: String, fileKey: String, fileName: String) {
        let token = AppState.shared.session?.accessToken ?? ""
        guard !token.isEmpty else { return }
        
        isDownloading = true
        downloadError = nil
        
        Task {
            do {
                let savedUrl = try await MessageResourceManager.shared.downloadAndSaveFile(
                    token: token,
                    messageId: messageId,
                    fileKey: fileKey,
                    fileName: fileName
                )
                self.downloadedUrl = savedUrl
                self.isDownloading = false
            } catch {
                self.downloadError = error.localizedDescription
                self.isDownloading = false
            }
        }
    }
}

public struct MessageFileView: View {
    let messageId: String
    let fileKey: String
    let fileName: String
    let fileSize: Int?
    
    @StateObject private var viewModel = MessageFileViewModel()
    
    public init(messageId: String, fileKey: String, fileName: String, fileSize: Int?) {
        self.messageId = messageId
        self.fileKey = fileKey
        self.fileName = fileName
        self.fileSize = fileSize
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // File Extension Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fileColor.opacity(0.15))
                    .frame(width: 42, height: 42)
                
                Image(systemName: fileSystemIcon)
                    .font(.system(size: 20))
                    .foregroundColor(fileColor)
            }
            
            // Name & Size
            VStack(alignment: .leading, spacing: 3) {
                Text(fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let size = fileSize {
                        Text(formattedFileSize(bytes: size))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = viewModel.downloadError {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    } else if viewModel.downloadedUrl != nil {
                        Text("✓ 已存至下载目录")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer(minLength: 12)
            
            // Action Button
            Button {
                viewModel.downloadFile(
                    messageId: messageId,
                    fileKey: fileKey,
                    fileName: fileName
                )
            } label: {
                if viewModel.isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else if viewModel.downloadedUrl != nil {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "3370FF"))
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "3370FF"))
                }
            }
            .buttonStyle(.plain)
            .help(viewModel.downloadedUrl != nil ? "在 Finder 中显示" : "下载此文件")
        }
        .padding(10)
        .frame(maxWidth: 320)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var fileSystemIcon: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text.fill"
        case "zip", "tar", "gz", "7z", "rar": return "doc.zipper"
        case "doc", "docx", "pages": return "doc.richtext.fill"
        case "xls", "xlsx", "numbers", "csv": return "tablecells.fill"
        case "ppt", "pptx", "key": return "play.rectangle.fill"
        case "mp3", "wav", "m4a", "flac": return "music.note"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "swift", "js", "ts", "py", "json", "html", "css", "c", "cpp", "go": return "curlybraces.square.fill"
        default: return "doc.fill"
        }
    }
    
    private var fileColor: Color {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return Color.red
        case "zip", "tar", "gz", "7z", "rar": return Color.orange
        case "doc", "docx": return Color.blue
        case "xls", "xlsx", "numbers", "csv": return Color.green
        case "ppt", "pptx": return Color.purple
        default: return Color(hex: "3370FF")
        }
    }
    
    private func formattedFileSize(bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }
}
