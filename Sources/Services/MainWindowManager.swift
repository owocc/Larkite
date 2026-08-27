import SwiftUI
import AppKit

@MainActor
public final class MainWindowManager: NSObject, NSWindowDelegate {
    public static let shared = MainWindowManager()
    
    private var windowController: NSWindowController?
    
    public override init() {
        super.init()
    }
    
    public func showMainWindow() {
        if let controller = windowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = MainView()
            .environmentObject(AppState.shared)
            .environmentObject(ConfigManager.shared)
            .preferredColorScheme(ConfigManager.shared.themeMode.colorScheme)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Larkite"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 860, height: 580)
        window.center()
        window.contentViewController = hostingController
        window.delegate = self
        
        let controller = NSWindowController(window: window)
        self.windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func hideMainWindow() {
        windowController?.window?.orderOut(nil)
    }
    
    public func closeMainWindow() {
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
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide on close rather than terminating so state is preserved
        sender.orderOut(nil)
        return false
    }
}
