import Foundation
import AppKit

/// Thread-safe in-memory and disk cache manager for message resource files (Images & Files)
/// Features in-flight task deduplication and negative caching to prevent spamming requests.
@MainActor
public final class MessageResourceManager: ObservableObject {
    public static let shared = MessageResourceManager()
    
    private var imageMemoryCache = NSCache<NSString, NSImage>()
    private var failedImageKeys = Set<String>()
    private var inFlightTasks: [String: Task<NSImage?, Never>] = [:]
    
    private init() {
        imageMemoryCache.countLimit = 300
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
        
        // 1. Check memory cache
        if let cached = imageMemoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        // 2. Check negative cache (do not re-request known failed/invalid keys)
        if failedImageKeys.contains(cacheKey) {
            return nil
        }
        
        // 3. Deduplicate in-flight requests
        if let existingTask = inFlightTasks[cacheKey] {
            return await existingTask.value
        }
        
        // 4. Create single network task
        let loadTask = Task<NSImage?, Never> {
            do {
                let data = try await FeishuAPIClient.shared.fetchMessageResource(
                    token: token,
                    messageId: messageId,
                    fileKey: fileKey,
                    type: "image"
                )
                
                if let image = NSImage(data: data) {
                    self.imageMemoryCache.setObject(image, forKey: cacheKey as NSString)
                    return image
                }
            } catch {
                // If message resource fails, try image download fallback once
                if let fallbackData = try? await FeishuAPIClient.shared.downloadImage(token: token, imageKey: fileKey),
                   let image = NSImage(data: fallbackData) {
                    self.imageMemoryCache.setObject(image, forKey: cacheKey as NSString)
                    return image
                }
            }
            
            // Mark as failed to avoid re-requesting on every scroll
            self.failedImageKeys.insert(cacheKey)
            return nil
        }
        
        inFlightTasks[cacheKey] = loadTask
        let result = await loadTask.value
        inFlightTasks.removeValue(forKey: cacheKey)
        return result
    }
    
    /// Downloads and saves a message file to user's Downloads directory
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
        
        var counter = 1
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        
        while FileManager.default.fileExists(atPath: destinationUrl.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            destinationUrl = downloadsUrl.appendingPathComponent(newName)
            counter += 1
        }
        
        try data.write(to: destinationUrl)
        NSWorkspace.shared.activateFileViewerSelecting([destinationUrl])
        
        return destinationUrl
    }
}
