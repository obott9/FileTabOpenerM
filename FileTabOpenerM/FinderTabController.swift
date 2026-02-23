// FinderTabController.swift
// FileTabOpenerM
//
// AXUIElement + AppleScript ハイブリッドで Finder タブを制御する
// ⭐ 設計意図: System Events keystroke を排除し、AX API で直接操作

import AppKit
@preconcurrency import ApplicationServices
import Combine

/// Finder タブ操作の結果
enum FinderTabResult {
    case success(tabCount: Int)
    case partialSuccess(opened: Int, failed: Int, errors: [String])
    case noFinderWindow
    case noTabBar
    case accessibilityDenied
    /// 無効パスあり (invalid: 無効パスリスト, validResult: 有効分の結果)
    indirect case invalidPaths(invalid: [String], validResult: FinderTabResult)
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

    /// 「新規タブ」ボタンを多言語対応で探索
    /// AX description は OS 言語に依存するため、主要言語すべてを網羅
    private static let newTabDescriptions = [
        "New Tab",           // en
        "新規タブ",           // ja
        "새로운 탭",          // ko
        "新增標籤頁",         // zh_TW
        "新建标签页",         // zh_CN
        "Nouvel onglet",     // fr
        "Neuer Tab",         // de
        "Nueva pestaña",     // es
        "Novo separador",    // pt
    ]

    private func findNewTabButton(_ appRef: AXUIElement) -> AXUIElement? {
        guard let win = frontWindow(appRef),
              let tg = findElement(win, role: "AXTabGroup") else { return nil }
        for desc in Self.newTabDescriptions {
            if let btn = findElement(tg, role: "AXButton", description: desc) {
                return btn
            }
        }
        // フォールバック: description に依存しない探索
        // TabGroup 内の最後の AXButton (通常「新規タブ」ボタン) を試す
        let buttons = axChildren(tg).filter { axString($0, kAXRoleAttribute) == "AXButton" }
        if let lastButton = buttons.last {
            logInfo("New Tab button found via fallback (last button in TabGroup)")
            return lastButton
        }
        return nil
    }

    private func tabCount(_ appRef: AXUIElement) -> Int {
        guard let win = frontWindow(appRef),
              let tg = findElement(win, role: "AXTabGroup") else { return 0 }
        return axChildren(tg).filter { axString($0, kAXSubroleAttribute) == "AXTabButton" }.count
    }

    /// タブ数変化を検出 (20ms ポーリング)
    /// ⚠️ 呼び出し元は nonisolated context で実行すること (UI ブロック防止)
    private nonisolated func waitForTabCountChange(
        _ appRef: AXUIElement, from expected: Int, timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // AX API はどのスレッドからでも呼べる
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement],
                  let win = windows.first else { continue }

            // TabGroup を探す
            var tgRef: AXUIElement?
            func findTG(_ element: AXUIElement) {
                var roleVal: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal) == .success,
                   let role = roleVal as? String, role == "AXTabGroup" {
                    tgRef = element
                    return
                }
                var childrenVal: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
                   let children = childrenVal as? [AXUIElement] {
                    for child in children {
                        if tgRef != nil { return }
                        findTG(child)
                    }
                }
            }
            findTG(win)

            if let tg = tgRef {
                var childrenVal: CFTypeRef?
                if AXUIElementCopyAttributeValue(tg, kAXChildrenAttribute as CFString, &childrenVal) == .success,
                   let children = childrenVal as? [AXUIElement] {
                    var count = 0
                    for child in children {
                        var subVal: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXSubroleAttribute as CFString, &subVal) == .success,
                           let sub = subVal as? String, sub == "AXTabButton" {
                            count += 1
                        }
                    }
                    if count != expected { return true }
                }
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

    /// Finder で新しいウィンドウを作成し、指定パスを表示
    private func createFinderWindow(_ path: String) -> Bool {
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            make new Finder window to (POSIX file "\(escaped)" as alias)
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        if let error = error {
            logError("Failed to create Finder window: \(error)")
            return false
        }
        logInfo("Created new Finder window for: \(path)")
        return true
    }

    /// タブバーを表示 — AX API でメニュー項目を操作 (System Events 不要)
    private func showTabBar(_ appRef: AXUIElement) -> Bool {
        // Finder のメニューバーから「表示」→「タブバーを表示」を AX API で実行
        guard let menuBarRef = axValue(appRef, kAXMenuBarAttribute) else {
            logError("Cannot access Finder menu bar")
            return false
        }
        let menuBar = menuBarRef as! AXUIElement

        let menuItems = axChildren(menuBar)
        // 「表示」メニューを探す (通常4番目: Finder, File, Edit, View)
        // 多言語対応: 位置ベースで探す (3番目 = index 3 が View メニュー)
        let viewMenuCandidates: [AXUIElement]
        if menuItems.count > 3 {
            viewMenuCandidates = [menuItems[3]] + menuItems.dropFirst(4)
        } else {
            viewMenuCandidates = Array(menuItems)
        }

        for menuItem in viewMenuCandidates {
            // メニューを開く
            guard axPress(menuItem) else { continue }
            usleep(100_000) // メニュー展開待ち

            // サブメニュー内で「タブバーを表示」/「Show Tab Bar」を探す
            let tabBarDescriptions = [
                "Show Tab Bar", "Hide Tab Bar",
                "タブバーを表示", "タブバーを非表示",
                "탭 막대 보기", "탭 막대 가리기",
                "顯示標籤列", "隱藏標籤列",
                "显示标签栏", "隐藏标签栏",
            ]

            for child in axChildren(menuItem) {
                for subItem in axChildren(child) {
                    let title = axString(subItem, kAXTitleAttribute) ?? ""
                    for desc in tabBarDescriptions {
                        if title.contains(desc) {
                            if axPress(subItem) {
                                logInfo("Tab bar toggled via AX menu: \(title)")
                                return true
                            }
                        }
                    }
                }
            }

            // このメニューに見つからなかった場合、閉じるために Escape
            _ = axPress(menuItem) // メニューを閉じる
        }

        logError("Tab bar menu item not found via AX")
        return false
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
    func openFoldersAsTabs(_ paths: [String], windowRect: NSRect? = nil,
                           timeout: TimeInterval = 5.0) async -> FinderTabResult {
        logInfo("openFoldersAsTabs: \(paths.count) paths requested")
        guard !paths.isEmpty else { return .success(tabCount: 0) }
        guard Self.isAccessibilityEnabled else {
            logError("Accessibility permission denied")
            return .accessibilityDenied
        }

        isOpening = true
        defer { isOpening = false }

        // パス重複除去 (順序維持)
        let deduplicated = Array(NSOrderedSet(array: paths)) as! [String]
        if deduplicated.count < paths.count {
            logInfo("\(paths.count - deduplicated.count) duplicate paths removed")
        }

        // バリデーション (有効/無効を分離)
        var validPaths: [String] = []
        var invalidPaths: [String] = []
        for path in deduplicated {
            if FileManager.default.fileExists(atPath: path) {
                validPaths.append(path)
            } else {
                invalidPaths.append(path)
            }
        }
        if !invalidPaths.isEmpty {
            logWarning("\(invalidPaths.count) invalid paths: \(invalidPaths)")
        }
        guard !validPaths.isEmpty else {
            if !invalidPaths.isEmpty {
                return .invalidPaths(invalid: invalidPaths, validResult: .success(tabCount: 0))
            }
            return .success(tabCount: 0)
        }

        guard let appRef = finderApp() else {
            logError("Finder app not found")
            return .noFinderWindow
        }

        // Finder をアクティブに
        NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        ).first?.activate()
        logInfo("Finder activated")

        // Finder の準備を待つ
        try? await Task.sleep(nanoseconds: 200_000_000)

        // 常に新規 Finder ウィンドウを作成 (既存ウィンドウは流用しない)
        logInfo("Creating new Finder window with: \(validPaths[0])")
        if !createFinderWindow(validPaths[0]) {
            logError("Failed to create Finder window")
            let result: FinderTabResult = .noFinderWindow
            if !invalidPaths.isEmpty {
                return .invalidPaths(invalid: invalidPaths, validResult: result)
            }
            return result
        }
        try? await Task.sleep(nanoseconds: 300_000_000)

        // ウィンドウの存在を確認
        guard frontWindow(appRef) != nil else {
            logError("No Finder window found after creation")
            let result: FinderTabResult = .noFinderWindow
            if !invalidPaths.isEmpty {
                return .invalidPaths(invalid: invalidPaths, validResult: result)
            }
            return result
        }

        // ウィンドウサイズ設定
        if let rect = windowRect {
            logInfo("Setting window bounds: \(rect)")
            setFinderBounds(rect)
        }

        var errors: [String] = []

        // パスが1つなら新規ウィンドウで完了 → タブ操作不要
        guard validPaths.count > 1 else {
            logInfo("Single path — no tab operations needed")
            let result: FinderTabResult = .success(tabCount: 1)
            if !invalidPaths.isEmpty {
                return .invalidPaths(invalid: invalidPaths, validResult: result)
            }
            return result
        }

        // タブバーの存在確認、なければ AX API で表示を試みる
        if findNewTabButton(appRef) == nil {
            logInfo("Tab bar not visible, attempting to show it via AX menu")
            if showTabBar(appRef) {
                // AX ツリー更新を待つ (showTabBar 後のアニメーション完了まで)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            // リトライ: AX ツリー更新が遅い場合に備えて最大3回
            var found = false
            for attempt in 1...3 {
                if findNewTabButton(appRef) != nil {
                    found = true
                    break
                }
                logInfo("Waiting for tab bar AX update (attempt \(attempt)/3)")
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            if !found {
                logError("Tab bar still not visible after show attempt")
                let result: FinderTabResult = .noTabBar
                if !invalidPaths.isEmpty {
                    return .invalidPaths(invalid: invalidPaths, validResult: result)
                }
                return result
            }
        }

        // 2番目以降: 新規タブ + パス設定
        let tabTimeout = timeout
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

            // UI ブロック回避: バックグラウンドでポーリング
            let changed = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInteractive).async {
                    let result = self.waitForTabCountChange(appRef, from: before, timeout: tabTimeout)
                    continuation.resume(returning: result)
                }
            }

            if !changed {
                logError("Tab count change timeout for: \(path)")
                errors.append(path)
                continue
            }

            if !setFinderTarget(path) {
                logError("Failed to set target: \(path)")
                errors.append(path)
            }
        }

        // フォールバック: 失敗したパスを個別ウィンドウで開く
        if !errors.isEmpty {
            logInfo("Fallback: opening \(errors.count) failed paths as separate windows")
            var fallbackRecovered = 0
            for path in errors {
                if createFinderWindow(path) {
                    fallbackRecovered += 1
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            if fallbackRecovered > 0 {
                logInfo("Fallback recovered \(fallbackRecovered)/\(errors.count) paths as separate windows")
            }
        }

        let opened = validPaths.count - errors.count
        let result: FinderTabResult
        if errors.isEmpty {
            logInfo("All \(opened) tabs opened successfully")
            result = .success(tabCount: opened)
        } else {
            logWarning("\(opened) succeeded, \(errors.count) failed (fallback attempted)")
            result = .partialSuccess(opened: opened, failed: errors.count, errors: errors)
        }

        if !invalidPaths.isEmpty {
            return .invalidPaths(invalid: invalidPaths, validResult: result)
        }
        return result
    }
}
