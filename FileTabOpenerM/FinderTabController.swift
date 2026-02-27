// FinderTabController.swift
// FileTabOpenerM
//
// AXUIElement + AppleScript ハイブリッドで Finder タブを制御する
// ⭐ 設計意図: System Events keystroke を排除し、AX API で直接操作
//
// 高速化:
//   D. AXUIElement キャッシュ — TabGroup / NewTabButton の再帰走査を排除
//   E. AXUIElementGetAttributeValueCount — 軽量タブ数変化検出
//   A. プリコンパイル済み NSAppleScript — タブ毎のコンパイルを排除

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
    @Published private(set) var openingCurrent = 0
    @Published private(set) var openingTotal = 0
    @Published private(set) var openingPath = ""

    // MARK: - AX キャッシュ (タブ操作ループ中に再利用)

    private var cachedTabGroup: AXUIElement?
    private var cachedNewTabButton: AXUIElement?

    private func clearCaches() {
        cachedTabGroup = nil
        cachedNewTabButton = nil
    }

    // MARK: - プリコンパイル済み AppleScript

    /// Apple Event constants (Carbon/OpenScripting.h)
    private static let aeScriptSuite: AEEventClass = 0x61736372   // 'ascr' kASAppleScriptSuite
    private static let aeSubroutineEvent: AEEventID = 0x70736272  // 'psbr' kASSubroutineEvent
    private static let aeKeySubroutineName: AEKeyword = 0x736E616D // 'snam' keyASSubroutineName
    private static let aeKeyDirectObject: AEKeyword = 0x2D2D2D2D  // '----' keyDirectObject

    /// 全 AppleScript ハンドラを1回だけコンパイル (以降はハンドラ呼び出しのみ)
    private lazy var compiledScript: NSAppleScript? = {
        let source = """
        on create_window(posix_path)
            tell application "Finder"
                make new Finder window to (POSIX file posix_path as alias)
            end tell
        end create_window

        on set_target(posix_path)
            tell application "Finder"
                set target of front Finder window to (POSIX file posix_path as alias)
            end tell
        end set_target

        on set_bounds(x1, y1, x2, y2)
            tell application "Finder"
                set bounds of front Finder window to {x1, y1, x2, y2}
            end tell
        end set_bounds
        """
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.compileAndReturnError(&error)
        if let error = error { logError("Failed to compile AppleScript: \(error)") }
        logInfo("AppleScript handlers compiled")
        return script
    }()

    /// プリコンパイル済みスクリプトのハンドラを呼び出す (再コンパイルなし)
    private func callHandler(_ name: String, params: NSAppleEventDescriptor) -> Bool {
        guard let script = compiledScript else { return false }
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: Self.aeScriptSuite,
            eventID: Self.aeSubroutineEvent,
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(
            NSAppleEventDescriptor(string: name),
            forKeyword: Self.aeKeySubroutineName
        )
        event.setParam(params, forKeyword: Self.aeKeyDirectObject)
        var error: NSDictionary?
        script.executeAppleEvent(event, error: &error)
        return error == nil
    }

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

    /// AXUIElement が有効か確認 (1 IPC コール)
    private func isValidAXElement(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success
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

    /// TabGroup を探す (キャッシュ付き — ループ中の繰り返し走査を排除)
    private func findTabGroup(_ appRef: AXUIElement) -> AXUIElement? {
        if let cached = cachedTabGroup, isValidAXElement(cached) {
            return cached
        }
        guard let win = frontWindow(appRef),
              let tg = findElement(win, role: "AXTabGroup") else { return nil }
        cachedTabGroup = tg
        return tg
    }

    /// 「新規タブ」ボタンを多言語対応で探索 (キャッシュ付き)
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
        // キャッシュが有効ならそのまま返す (1 IPC で検証)
        if let cached = cachedNewTabButton, isValidAXElement(cached) {
            return cached
        }
        guard let tg = findTabGroup(appRef) else { return nil }
        for desc in Self.newTabDescriptions {
            if let btn = findElement(tg, role: "AXButton", description: desc) {
                cachedNewTabButton = btn
                return btn
            }
        }
        // フォールバック: description に依存しない探索
        // TabGroup 内の最後の AXButton (通常「新規タブ」ボタン) を試す
        let buttons = axChildren(tg).filter { axString($0, kAXRoleAttribute) == "AXButton" }
        if let lastButton = buttons.last {
            logInfo("New Tab button found via fallback (last button in TabGroup)")
            cachedNewTabButton = lastButton
            return lastButton
        }
        return nil
    }

    /// 条件が true になるまで 50ms 間隔でポーリング (async、UI ブロックなし)
    private func pollUntil(timeout: TimeInterval, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    /// TabGroup の子要素数を軽量に取得 (1 IPC コール、再帰走査なし)
    private func tabChildCount(_ tabGroup: AXUIElement) -> CFIndex {
        var count: CFIndex = 0
        AXUIElementGetAttributeValueCount(tabGroup, kAXChildrenAttribute as CFString, &count)
        return count
    }

    /// タブ数変化を検出 (20ms ポーリング、軽量カウント API 使用)
    /// 現旧: 毎ポーリングで AX ツリー全再帰走査 → 改善: 1 IPC コール/ポーリング
    /// ⚠️ 呼び出し元は nonisolated context で実行すること (UI ブロック防止)
    private nonisolated func waitForTabCountChange(
        _ tabGroup: AXUIElement, from expected: CFIndex, timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var count: CFIndex = 0
            if AXUIElementGetAttributeValueCount(
                tabGroup, kAXChildrenAttribute as CFString, &count
            ) == .success, count != expected {
                return true
            }
            usleep(20_000)
        }
        return false
    }

    // MARK: - AppleScript (プリコンパイル済みハンドラ経由)

    private func setFinderTarget(_ path: String) -> Bool {
        let params = NSAppleEventDescriptor.list()
        params.insert(NSAppleEventDescriptor(string: path), at: 1)
        return callHandler("set_target", params: params)
    }

    private func setFinderBounds(_ rect: NSRect) {
        let params = NSAppleEventDescriptor.list()
        params.insert(NSAppleEventDescriptor(int32: Int32(rect.origin.x)), at: 1)
        params.insert(NSAppleEventDescriptor(int32: Int32(rect.origin.y)), at: 2)
        params.insert(NSAppleEventDescriptor(int32: Int32(rect.origin.x + rect.size.width)), at: 3)
        params.insert(NSAppleEventDescriptor(int32: Int32(rect.origin.y + rect.size.height)), at: 4)
        _ = callHandler("set_bounds", params: params)
    }

    /// Finder で新しいウィンドウを作成し、指定パスを表示
    private func createFinderWindow(_ path: String) -> Bool {
        let params = NSAppleEventDescriptor.list()
        params.insert(NSAppleEventDescriptor(string: path), at: 1)
        let success = callHandler("create_window", params: params)
        if success {
            logInfo("Created new Finder window for: \(path)")
        } else {
            logError("Failed to create Finder window: \(path)")
        }
        return success
    }

    /// タブバーを表示 — AX API でメニュー項目を操作 (System Events 不要)
    private func showTabBar(_ appRef: AXUIElement) -> Bool {
        // Finder のメニューバーから「表示」→「タブバーを表示」を AX API で実行
        guard let menuBarRef = axValue(appRef, kAXMenuBarAttribute) else {
            logError("Cannot access Finder menu bar")
            return false
        }
        // CFTypeRef → AXUIElement (CoreFoundation type, cast always succeeds)
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
        openingTotal = paths.count
        openingCurrent = 0
        openingPath = ""
        defer {
            isOpening = false
            openingCurrent = 0
            openingTotal = 0
            openingPath = ""
        }

        // 新しいウィンドウを開くのでキャッシュをクリア
        clearCaches()

        // パス重複除去 (順序維持)
        let deduplicated = NSOrderedSet(array: paths).array.compactMap { $0 as? String }
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

        // 常に新規 Finder ウィンドウを作成 (既存ウィンドウは流用しない)
        openingCurrent = 1
        openingPath = validPaths[0]
        logInfo("Creating new Finder window with: \(validPaths[0])")
        if !createFinderWindow(validPaths[0]) {
            logError("Failed to create Finder window")
            let result: FinderTabResult = .noFinderWindow
            if !invalidPaths.isEmpty {
                return .invalidPaths(invalid: invalidPaths, validResult: result)
            }
            return result
        }

        // ウィンドウ出現をポーリング (固定スリープではなく条件駆動)
        let windowReady = await pollUntil(timeout: 3.0, { self.frontWindow(appRef) != nil })
        if !windowReady {
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
            _ = showTabBar(appRef)

            // New Tab ボタン出現をポーリング
            let tabBarReady = await pollUntil(timeout: 3.0, { self.findNewTabButton(appRef) != nil })
            if !tabBarReady {
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
            openingCurrent = i + 2
            openingPath = path
            logInfo("Opening tab \(i + 2)/\(validPaths.count): \(path)")
            guard let btn = findNewTabButton(appRef) else {
                logError("New Tab button not found for: \(path)")
                errors.append(path)
                continue
            }

            // キャッシュ済み TabGroup から軽量カウント (1 IPC)
            guard let tg = findTabGroup(appRef) else {
                logError("TabGroup not found for: \(path)")
                errors.append(path)
                continue
            }
            let before = tabChildCount(tg)

            guard axPress(btn) else {
                logError("AXPress failed for: \(path)")
                errors.append(path)
                continue
            }

            // UI ブロック回避: バックグラウンドで軽量ポーリング
            let changed = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInteractive).async {
                    let result = self.waitForTabCountChange(tg, from: before, timeout: tabTimeout)
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
