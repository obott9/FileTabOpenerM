// FinderTabController.swift
// FileTabOpenerM
//
// AXUIElement + AppleScript ハイブリッドで Finder タブを制御する

import AppKit
import ApplicationServices
import Combine

/// Finder タブ操作の結果
enum FinderTabResult {
    case success(tabCount: Int)
    case partialSuccess(opened: Int, failed: Int, errors: [String])
    case noFinderWindow
    case noTabBar
    case accessibilityDenied
}

/// AXUIElement + AppleScript ハイブリッドで Finder タブを制御
final class FinderTabController: ObservableObject {

    @Published private(set) var isOpening = false

    // MARK: - AX ヘルパー (private)

    private func axValue(_ element: AXUIElement, _ attr: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success ? value : nil
    }

    private func axString(_ element: AXUIElement, _ attr: String) -> String? {
        axValue(element, attr) as? String
    }

    private func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        axValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private func axPress(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    /// 再帰的に要素を探す
    private func findElement(_ root: AXUIElement, role: String,
                             description: String? = nil, subrole: String? = nil) -> AXUIElement? {
        let r = axString(root, kAXRoleAttribute) ?? ""
        let d = axString(root, kAXDescriptionAttribute) ?? ""
        let s = axString(root, kAXSubroleAttribute) ?? ""

        var match = (r == role)
        if let description { match = match && d.contains(description) }
        if let subrole { match = match && (s == subrole) }
        if match { return root }

        for child in axChildren(root) {
            if let found = findElement(child, role: role, description: description, subrole: subrole) {
                return found
            }
        }
        return nil
    }

    // MARK: - Finder AX アクセス

    private func finderApp() -> AXUIElement? {
        guard let finder = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        ).first else { return nil }
        return AXUIElementCreateApplication(finder.processIdentifier)
    }

    private func frontWindow(_ appRef: AXUIElement) -> AXUIElement? {
        (axValue(appRef, kAXWindowsAttribute) as? [AXUIElement])?.first
    }

    private func findNewTabButton(_ appRef: AXUIElement) -> AXUIElement? {
        guard let win = frontWindow(appRef),
              let tg = findElement(win, role: "AXTabGroup") else { return nil }
        return findElement(tg, role: "AXButton", description: "新規タブ")
            ?? findElement(tg, role: "AXButton", description: "New Tab")
    }

    private func tabCount(_ appRef: AXUIElement) -> Int {
        guard let win = frontWindow(appRef),
              let tg = findElement(win, role: "AXTabGroup") else { return 0 }
        return axChildren(tg).filter { axString($0, kAXSubroleAttribute) == "AXTabButton" }.count
    }

    /// タブ数変化を検出 (20ms ポーリング, タイムアウト5秒)
    private func waitForTabCountChange(_ appRef: AXUIElement, from expected: Int,
                                        timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if tabCount(appRef) != expected {
                return true
            }
            usleep(20_000)
        }
        return false
    }

    // MARK: - AppleScript

    private func setFinderTarget(_ path: String) -> Bool {
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            set target of front Finder window to (POSIX file "\(escaped)" as alias)
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        return error == nil
    }

    private func setFinderBounds(_ rect: NSRect) {
        let script = """
        tell application "Finder"
            set bounds of front Finder window to {\(Int(rect.origin.x)), \(Int(rect.origin.y)), \(Int(rect.origin.x + rect.size.width)), \(Int(rect.origin.y + rect.size.height))}
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
    }

    // MARK: - 公開 API

    /// アクセシビリティ権限の確認
    static var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// アクセシビリティ権限をリクエスト (設定画面を開く)
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// 複数パスを Finder タブとして開く
    @MainActor
    func openFoldersAsTabs(_ paths: [String], windowRect: NSRect? = nil) async -> FinderTabResult {
        logInfo("openFoldersAsTabs: \(paths.count) paths requested")
        guard !paths.isEmpty else { return .success(tabCount: 0) }
        guard Self.isAccessibilityEnabled else {
            logError("Accessibility permission denied")
            return .accessibilityDenied
        }

        isOpening = true
        defer { isOpening = false }

        // バリデーション
        let validPaths = paths.filter { FileManager.default.fileExists(atPath: $0) }
        let invalidCount = paths.count - validPaths.count
        if invalidCount > 0 {
            logWarning("\(invalidCount) invalid paths filtered out")
        }
        guard !validPaths.isEmpty else { return .success(tabCount: 0) }

        guard let appRef = finderApp() else {
            logError("Finder app not found")
            return .noFinderWindow
        }

        // Finder をアクティブに
        NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        ).first?.activate()
        logInfo("Finder activated")

        // Finder の準備を待つ (変化検出ではなく初期化待ち)
        try? await Task.sleep(nanoseconds: 200_000_000)

        guard frontWindow(appRef) != nil else {
            logError("No Finder window found")
            return .noFinderWindow
        }

        // タブバーの存在確認
        guard findNewTabButton(appRef) != nil else {
            logError("Tab bar not visible (New Tab button not found)")
            return .noTabBar
        }

        var errors: [String] = []

        // 最初のパス: 既存タブに設定
        logInfo("Setting first tab target: \(validPaths[0])")
        if !setFinderTarget(validPaths[0]) {
            logError("Failed to set target: \(validPaths[0])")
            errors.append(validPaths[0])
        }

        // ウィンドウサイズ設定
        if let rect = windowRect {
            logInfo("Setting window bounds: \(rect)")
            setFinderBounds(rect)
        }

        // 2番目以降: 新規タブ + パス設定
        for (i, path) in validPaths.dropFirst().enumerated() {
            logInfo("Opening tab \(i + 2)/\(validPaths.count): \(path)")
            guard let btn = findNewTabButton(appRef) else {
                logError("New Tab button not found for: \(path)")
                errors.append(path)
                continue
            }

            let before = tabCount(appRef)
            guard axPress(btn) else {
                logError("AXPress failed for: \(path)")
                errors.append(path)
                continue
            }

            if !waitForTabCountChange(appRef, from: before) {
                logError("Tab count change timeout for: \(path)")
                errors.append(path)
                continue
            }

            if !setFinderTarget(path) {
                logError("Failed to set target: \(path)")
                errors.append(path)
            }
        }

        let opened = validPaths.count - errors.count
        if errors.isEmpty {
            logInfo("All \(opened) tabs opened successfully")
            return .success(tabCount: opened)
        } else {
            logWarning("\(opened) succeeded, \(errors.count) failed")
            return .partialSuccess(opened: opened, failed: errors.count, errors: errors)
        }
    }
}
