import SwiftUI
import AppKit

@MainActor
public final class AccountWindowManager: NSObject, NSWindowDelegate {
    public static let shared = AccountWindowManager()
    
    private var window: NSWindow?
    
    public override init() {
        super.init()
    }
    
    public func showLoginWindow() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = AccountWindowContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Lark Native 账号与登录中心"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 560, height: 620)
        newWindow.center()
        newWindow.contentViewController = hostingController
        newWindow.delegate = self
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func closeWindow() {
        window?.close()
        self.window = nil
    }
    
    public func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}

public struct AccountWindowContentView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var configManager: ConfigManager = .shared
    
    public init() {}
    
    public var body: some View {
        LoginView()
            .preferredColorScheme(configManager.themeMode.colorScheme)
    }
}
