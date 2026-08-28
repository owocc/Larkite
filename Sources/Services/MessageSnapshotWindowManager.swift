import SwiftUI
import AppKit

@MainActor
public final class MessageSnapshotWindowManager: NSObject, NSWindowDelegate {
    public static let shared = MessageSnapshotWindowManager()
    
    private var windowController: NSWindowController?
    
    public override init() {
        super.init()
    }
    
    public func showSnapshotWindow(messages: [FeishuMessageItem], chat: FeishuChatItem) {
        if let controller = windowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = MessageSnapshotViewer(messages: messages, chat: chat)
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "生成消息卡片分享"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 520)
        window.center()
        window.contentViewController = hostingController
        window.delegate = self
        
        let controller = NSWindowController(window: window)
        self.windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func closeWindow() {
        windowController?.close()
        DispatchQueue.main.async { [weak self] in
            self?.windowController = nil
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.windowController = nil
        }
    }
}
