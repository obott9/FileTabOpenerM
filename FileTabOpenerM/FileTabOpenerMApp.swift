//
//  FileTabOpenerMApp.swift
//  FileTabOpenerM
//
//  Created by 尾保手　秀樹 on 2026/02/24.
//

import SwiftUI

@main
struct FileTabOpenerMApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 800, height: 600)
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
