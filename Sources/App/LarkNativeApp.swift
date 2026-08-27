import SwiftUI
import AppKit

@main
struct LarkNativeApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var configManager = ConfigManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .environmentObject(configManager)
                .preferredColorScheme(configManager.themeMode.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 660)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("账号与组织") {
                Button("登录 / 切换企业账号...") {
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
