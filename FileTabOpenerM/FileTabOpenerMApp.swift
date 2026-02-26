//
//  FileTabOpenerMApp.swift
//  FileTabOpenerM
//
//  Created by 尾保手　秀樹 on 2026/02/24.
//

import SwiftUI

// S6: Keyboard shortcut notifications
extension Notification.Name {
    static let addTabGroup = Notification.Name("addTabGroup")
    static let deleteTabGroup = Notification.Name("deleteTabGroup")
    static let openTabs = Notification.Name("openTabs")
}

@main
struct FileTabOpenerMApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            // S6: Keyboard shortcuts (⌘N, ⌘Delete, ⌘O)
            CommandGroup(after: .newItem) {
                Button(L("dialog.add_tab")) {
                    NotificationCenter.default.post(name: .addTabGroup, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(L("tab.delete")) {
                    NotificationCenter.default.post(name: .deleteTabGroup, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Divider()

                Button(L("action.open_tabs")) {
                    NotificationCenter.default.post(name: .openTabs, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

// MARK: - AppDelegate (ウィンドウジオメトリ保存/復元)

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("Application launched")

        // ウィンドウジオメトリ復元
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.restoreWindowGeometry()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowGeometry()
        logInfo("Application terminated")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - ジオメトリ管理

    private func restoreWindowGeometry() {
        let geo = ConfigManager.shared.config.windowGeometry
        guard !geo.isEmpty else { return }
        let parts = geo.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w >= 600, h >= 400 else { return }

        if let window = NSApplication.shared.windows.first {
            var frame = window.frame
            frame.size = NSSize(width: w, height: h)
            window.setFrame(frame, display: true, animate: false)
            logInfo("Window geometry restored: \(Int(w))x\(Int(h))")
        }
    }

    private func saveWindowGeometry() {
        guard let window = NSApplication.shared.windows.first else { return }
        let size = window.frame.size
        let geo = "\(Int(size.width))x\(Int(size.height))"
        if ConfigManager.shared.config.windowGeometry != geo {
            ConfigManager.shared.config.windowGeometry = geo
            ConfigManager.shared.save()
            logInfo("Window geometry saved: \(geo)")
        }
    }
}
