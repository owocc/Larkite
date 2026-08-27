import Foundation
import AppKit

/// Thread-safe in-memory and disk cache manager for message resource files (Images & Files)
@MainActor
public final class MessageResourceManager: ObservableObject {
    public static let shared = MessageResourceManager()
    
    private var imageMemoryCache = NSCache<NSString, NSImage>()
    private var dataMemoryCache = NSCache<NSString, NSData>()
    private var loadingKeys = Set<String>()
    
    private init() {
        imageMemoryCache.countLimit = 200
        dataMemoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }
    
    /// Returns cached NSImage if available
    public func getCachedImage(key: String) -> NSImage? {
        imageMemoryCache.object(forKey: key as NSString)
    }
    
    /// Loads image resource with token from Feishu OpenAPI
    public func loadImage(
        token: String,
        messageId: String,
        fileKey: String
    ) async -> NSImage? {
        let cacheKey = "\(messageId)_\(fileKey)"
        
        if let cached = imageMemoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        if loadingKeys.contains(cacheKey) {
            // Wait briefly if already loading
            try? await Task.sleep(nanoseconds: 200_000_000)
            return imageMemoryCache.object(forKey: cacheKey as NSString)
        }
        
        loadingKeys.insert(cacheKey)
        defer { loadingKeys.remove(cacheKey) }
        
        do {
            let data = try await FeishuAPIClient.shared.fetchMessageResource(
                token: token,
                messageId: messageId,
                fileKey: fileKey,
                type: "image"
            )
            
            if let image = NSImage(data: data) {
                imageMemoryCache.setObject(image, forKey: cacheKey as NSString)
                return image
            }
        } catch {
            // Try downloading with image API as fallback
            if let fallbackData = try? await FeishuAPIClient.shared.downloadImage(token: token, imageKey: fileKey),
               let image = NSImage(data: fallbackData) {
                imageMemoryCache.setObject(image, forKey: cacheKey as NSString)
                return image
            }
        }
        
        return nil
    }
    
    /// Downloads and saves a message file to user's Downloads directory or prompt
    public func downloadAndSaveFile(
        token: String,
        messageId: String,
        fileKey: String,
        fileName: String
    ) async throws -> URL {
        let data = try await FeishuAPIClient.shared.fetchMessageResource(
            token: token,
            messageId: messageId,
            fileKey: fileKey,
            type: "file"
        )
        
        let downloadsUrl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var destinationUrl = downloadsUrl.appendingPathComponent(fileName)
        
        // Avoid overwriting existing file
        var counter = 1
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        
        while FileManager.default.fileExists(atPath: destinationUrl.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            destinationUrl = downloadsUrl.appendingPathComponent(newName)
            counter += 1
        }
        
        try data.write(to: destinationUrl)
        
        // Reveal in Finder
        NSWorkspace.shared.activateFileViewerSelecting([destinationUrl])
        
        return destinationUrl
    }
}
