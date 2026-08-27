import SwiftUI
import AppKit

@main
struct LarkiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var configManager = ConfigManager.shared
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(configManager)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    SettingsWindowManager.shared.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("账号与组织") {
                Button("登录更多账号...") {
                    AccountWindowManager.shared.showLoginWindow()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
            CommandMenu("会话与群组") {
                Button("刷新群组列表") {
                    Task {
                        await AppState.shared.loadChats(reset: true)
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("聚焦搜索") {
                    // Quick command
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppState.shared.isLoggedIn {
            MainWindowManager.shared.showMainWindow()
        } else {
            AccountWindowManager.shared.showLoginWindow()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if AppState.shared.isLoggedIn {
                MainWindowManager.shared.showMainWindow()
            } else {
                AccountWindowManager.shared.showLoginWindow()
            }
        }
        return true
    }
}
