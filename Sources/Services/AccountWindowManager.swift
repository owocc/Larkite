import SwiftUI
import AppKit

@MainActor
public final class AccountWindowManager: NSObject, NSWindowDelegate {
    public static let shared = AccountWindowManager()
    
    private var windowController: NSWindowController?
    
    public override init() {
        super.init()
    }
    
    public func showLoginWindow() {
        if let controller = windowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = AccountWindowContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 375),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Lark Native 账号与登录中心"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 345)
        window.maxSize = NSSize(width: 560, height: 420)
        window.center()
        window.contentViewController = hostingController
        window.delegate = self
        
        let controller = NSWindowController(window: window)
        self.windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    public func closeWindow() {
        AppState.shared.cancelOAuthLogin()
        windowController?.close()
        DispatchQueue.main.async { [weak self] in
            self?.windowController = nil
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        AppState.shared.cancelOAuthLogin()
        DispatchQueue.main.async { [weak self] in
            self?.windowController = nil
        }
    }
}

public struct AccountWindowContentView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init() {}
    
    public var body: some View {
        LoginView()
    }
}
