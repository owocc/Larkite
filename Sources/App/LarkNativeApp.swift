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
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
            
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
