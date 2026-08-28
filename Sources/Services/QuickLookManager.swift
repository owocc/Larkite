import SwiftUI
import AppKit
import QuickLookUI

public final class QuickLookPreviewItem: NSObject, QLPreviewItem, @unchecked Sendable {
    public let previewItemURL: URL?
    public let previewItemTitle: String?
    
    public init(url: URL, title: String? = nil) {
        self.previewItemURL = url
        self.previewItemTitle = title ?? url.lastPathComponent
        super.init()
    }
}

public final class QuickLookManager: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate, @unchecked Sendable {
    public static let shared = QuickLookManager()
    
    private let lock = NSLock()
    private var _currentItem: QuickLookPreviewItem?
    
    private var currentItem: QuickLookPreviewItem? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentItem
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _currentItem = newValue
        }
    }
    
    public override init() {
        super.init()
    }
    
    /// Opens the native macOS spacebar Quick Look preview panel instantaneously (zero cold-start delay)
    @MainActor
    public func preview(url: URL, title: String? = nil) {
        self.currentItem = QuickLookPreviewItem(url: url, title: title)
        
        guard let panel = QLPreviewPanel.shared() else {
            NSWorkspace.shared.open(url)
            return
        }
        
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        
        if !panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    // MARK: - QLPreviewPanelDataSource
    
    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentItem != nil ? 1 : 0
    }
    
    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return currentItem
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    public func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        if let window = NSApp.keyWindow {
            return NSRect(x: window.frame.midX - 180, y: window.frame.midY - 180, width: 360, height: 360)
        }
        return .zero
    }
}
