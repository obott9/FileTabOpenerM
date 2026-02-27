// ContentView+Actions.swift
// FileTabOpenerM
//
// ContentView のアクションメソッド (ロジック全般)
// ContentView.swift から分離

import SwiftUI
import UniformTypeIdentifiers

extension ContentView {

    // MARK: - 初期化

    func loadInitialState() {
        logInfo("App started — language: \(Localization.shared.currentLanguage), timeout: \(configManager.config.settings.timeout)s")
        if configManager.config.tabGroups.isEmpty {
            configManager.addTabGroup(name: "Tab 1")
        }
        selectedGroupID = configManager.config.tabGroups.first?.id
        loadGeometry()

        // アクセシビリティ権限の起動時チェック
        if !FinderTabController.isAccessibilityEnabled {
            logWarning("Accessibility permission not granted at launch")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showAccessibilityDialog()
            }
        }
    }

    func addGroupFromTextField() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if configManager.config.tabGroups.contains(where: { $0.name == name }) {
            showAlert(title: L("dialog.duplicate"), message: L("dialog.duplicate_msg").localized(name))
            return
        }
        configManager.addTabGroup(name: name)
        selectedGroupID = configManager.config.tabGroups.last?.id
        newGroupName = ""
        loadGeometry()
    }

    func selectGroup(_ id: UUID) {
        saveGeometry()
        selectedGroupID = id
        selectedPathIndex = nil
        loadGeometry()
    }

    // MARK: - タブグループ管理

    func addTabGroup() {
        guard let name = showInputDialog(
            title: L("dialog.add_tab"),
            message: L("dialog.enter_tab_name"),
            defaultValue: "Tab \(configManager.config.tabGroups.count + 1)"
        ) else { return }
        if configManager.config.tabGroups.contains(where: { $0.name == name }) {
            showAlert(title: L("dialog.duplicate"), message: L("dialog.duplicate_msg").localized(name))
            return
        }
        configManager.addTabGroup(name: name)
        selectedGroupID = configManager.config.tabGroups.last?.id
        loadGeometry()
    }

    func deleteSelectedGroup() {
        guard let id = selectedGroupID,
              let index = selectedGroupIndex else { return }
        let name = configManager.config.tabGroups[index].name
        guard showConfirmDialog(
            title: L("dialog.delete_title"),
            message: L("dialog.delete_msg").localized(name)
        ) else { return }

        let groups = configManager.config.tabGroups
        let newSelection: UUID?
        if groups.count <= 1 {
            newSelection = nil
        } else if index < groups.count - 1 {
            newSelection = groups[index + 1].id
        } else {
            newSelection = groups[index - 1].id
        }

        configManager.deleteTabGroup(id: id)
        selectedGroupID = newSelection
        loadGeometry()
    }

    func renameSelectedGroup() {
        guard let index = selectedGroupIndex else { return }
        let oldName = configManager.config.tabGroups[index].name
        guard let newName = showInputDialog(
            title: L("dialog.rename"),
            message: L("dialog.enter_name"),
            defaultValue: oldName
        ) else { return }
        if newName == oldName { return }
        if configManager.config.tabGroups.contains(where: { $0.name == newName }) {
            showAlert(title: L("dialog.duplicate"), message: L("dialog.duplicate_msg").localized(newName))
            return
        }
        logInfo("Tab group renamed: \(oldName) -> \(newName)")
        configManager.config.tabGroups[index].name = newName
        configManager.save()
    }

    func copySelectedGroup() {
        guard let id = selectedGroupID else { return }
        configManager.duplicateTabGroup(id: id)
        if let origIndex = configManager.config.tabGroups.firstIndex(where: { $0.id == id }),
           origIndex + 1 < configManager.config.tabGroups.count {
            selectedGroupID = configManager.config.tabGroups[origIndex + 1].id
        }
        loadGeometry()
    }

    func moveSelectedGroupLeft() {
        guard let index = selectedGroupIndex, index > 0 else { return }
        configManager.config.tabGroups.swapAt(index, index - 1)
        configManager.save()
    }

    func moveSelectedGroupRight() {
        guard let index = selectedGroupIndex,
              index < configManager.config.tabGroups.count - 1 else { return }
        configManager.config.tabGroups.swapAt(index, index + 1)
        configManager.save()
    }

    // MARK: - パス管理

    func addPathFromEntry() {
        let path = sanitizePath(newPath)
        guard !path.isEmpty, let gi = selectedGroupIndex else { return }
        let expanded = NSString(string: path).expandingTildeInPath

        // 存在確認
        if !FileManager.default.fileExists(atPath: expanded) {
            logWarning("Path not found: \(expanded)")
            showAlert(title: L("error.title"), message: L("error.path_not_found").localized(expanded))
            return
        }

        // 重複チェック
        if configManager.config.tabGroups[gi].paths.contains(expanded) {
            logWarning("Duplicate path: \(expanded)")
            showAlert(title: L("error.warning"), message: L("error.duplicate_path").localized(expanded))
            return
        }

        logInfo("Path added: \(expanded)")
        configManager.config.tabGroups[gi].paths.append(expanded)
        configManager.save()
        newPath = ""
    }

    func removeSelectedPath() {
        guard let gi = selectedGroupIndex,
              let pi = selectedPathIndex,
              configManager.config.tabGroups[gi].paths.indices.contains(pi) else { return }
        let removed = configManager.config.tabGroups[gi].paths[pi]
        logInfo("Path removed: \(removed)")
        configManager.config.tabGroups[gi].paths.remove(at: pi)
        configManager.save()
        selectedPathIndex = nil
    }

    func movePathUp() {
        guard let gi = selectedGroupIndex,
              let pi = selectedPathIndex, pi > 0 else { return }
        configManager.config.tabGroups[gi].paths.swapAt(pi, pi - 1)
        configManager.save()
        selectedPathIndex = pi - 1
    }

    func movePathDown() {
        guard let gi = selectedGroupIndex,
              let pi = selectedPathIndex,
              pi < configManager.config.tabGroups[gi].paths.count - 1 else { return }
        configManager.config.tabGroups[gi].paths.swapAt(pi, pi + 1)
        configManager.save()
        selectedPathIndex = pi + 1
    }

    func deletePath(at index: Int, in groupIndex: Int) {
        guard configManager.config.tabGroups[groupIndex].paths.indices.contains(index) else { return }
        let removed = configManager.config.tabGroups[groupIndex].paths[index]
        logInfo("Path removed: \(removed)")
        configManager.config.tabGroups[groupIndex].paths.remove(at: index)
        configManager.save()
        selectedPathIndex = nil
    }

    func deletePathsAtOffsets(_ offsets: IndexSet) {
        guard let gi = selectedGroupIndex else { return }
        for index in offsets.sorted().reversed() {
            logInfo("Path removed: \(configManager.config.tabGroups[gi].paths[index])")
        }
        configManager.config.tabGroups[gi].paths.remove(atOffsets: offsets)
        configManager.save()
        selectedPathIndex = nil
    }

    func movePathsFromOffsets(_ from: IndexSet, to: Int) {
        guard let gi = selectedGroupIndex else { return }
        configManager.config.tabGroups[gi].paths.move(fromOffsets: from, toOffset: to)
        configManager.save()
    }

    func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = L("path.placeholder")
        if panel.runModal() == .OK, let url = panel.urls.first {
            newPath = url.path
            logInfo("Folder selected via browse: \(url.path)")
        }
    }

    // MARK: - ドラッグ&ドロップ

    func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                self.newPath = url.path
                logInfo("Path dropped: \(url.path)")
            }
        }
        return true
    }

    func handleFileDropToHistory(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                self.historyText = url.path
                logInfo("Path dropped to history: \(url.path)")
            }
        }
        return true
    }

    // MARK: - ジオメトリ

    func loadGeometry() {
        guard let gi = selectedGroupIndex else {
            geomX = ""; geomY = ""; geomW = ""; geomH = ""
            return
        }
        let g = configManager.config.tabGroups[gi]
        geomX = g.windowX.map(String.init) ?? ""
        geomY = g.windowY.map(String.init) ?? ""
        geomW = g.windowWidth.map(String.init) ?? ""
        geomH = g.windowHeight.map(String.init) ?? ""
    }

    func saveGeometry() {
        guard let gi = selectedGroupIndex else { return }
        // Screen bounds for validation
        let screenW = Int(NSScreen.main?.frame.width ?? 3840)
        let screenH = Int(NSScreen.main?.frame.height ?? 2160)
        let maxW = screenW * 2   // multi-monitor support
        let maxH = screenH * 2

        configManager.config.tabGroups[gi].windowX = clampRange(Int(geomX), -screenW, screenW)
        configManager.config.tabGroups[gi].windowY = clampRange(Int(geomY), -screenH, screenH)
        configManager.config.tabGroups[gi].windowWidth = clampRange(Int(geomW), 528, maxW)
        configManager.config.tabGroups[gi].windowHeight = clampRange(Int(geomH), 308, maxH)
        // Reflect clamped values back to text fields
        if let x = configManager.config.tabGroups[gi].windowX { geomX = String(x) }
        if let y = configManager.config.tabGroups[gi].windowY { geomY = String(y) }
        if let w = configManager.config.tabGroups[gi].windowWidth { geomW = String(w) }
        if let h = configManager.config.tabGroups[gi].windowHeight { geomH = String(h) }
        configManager.save()
    }

    /// Clamp a value to [min, max]. Returns nil if value is nil (empty field).
    func clampRange(_ value: Int?, _ minimum: Int, _ maximum: Int) -> Int? {
        guard let v = value else { return nil }
        return max(minimum, min(v, maximum))
    }

    func getFinderBounds() {
        logInfo("Getting Finder window bounds")
        let script = """
        tell application "Finder" to get bounds of front Finder window
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        guard let result = appleScript?.executeAndReturnError(&error),
              result.numberOfItems == 4 else {
            logError("Failed to get Finder bounds: \(error ?? [:])")
            showAlert(title: L("error.title"), message: L("error.no_finder_window"))
            return
        }
        let x1 = Int(result.atIndex(1)?.int32Value ?? 0)
        let y1 = Int(result.atIndex(2)?.int32Value ?? 0)
        let x2 = Int(result.atIndex(3)?.int32Value ?? 0)
        let y2 = Int(result.atIndex(4)?.int32Value ?? 0)
        geomX = String(x1)
        geomY = String(y1)
        geomW = String(x2 - x1)
        geomH = String(y2 - y1)
        logInfo("Finder bounds: x=\(x1) y=\(y1) w=\(x2 - x1) h=\(y2 - y1)")
        saveGeometry()
    }

    // MARK: - 履歴

    func openSingleFolder() {
        let path = sanitizePath(historyText)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            logWarning("Path not found: \(expanded)")
            showAlert(title: L("error.title"), message: L("error.path_not_found").localized(path))
            return
        }
        logInfo("Opening single folder: \(expanded)")
        configManager.addHistory(path: expanded)
        NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
    }

    func toggleHistoryPin() {
        let path = historyText.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        if !configManager.config.history.contains(where: { $0.path == expanded }) {
            configManager.addHistory(path: expanded)
        }
        configManager.togglePin(path: expanded)
        logInfo("History pin toggled: \(expanded)")
    }

    func clearHistory() {
        guard showConfirmDialog(
            title: L("dialog.clear_history"),
            message: L("dialog.clear_history_msg")
        ) else { return }
        configManager.clearHistory(keepPinned: true)
    }

    // MARK: - タブで開く

    func openTabs() {
        guard let gi = selectedGroupIndex else { return }
        let group = configManager.config.tabGroups[gi]
        saveGeometry()
        logInfo("Opening tabs for group: \(group.name) (\(group.paths.count) paths)")

        Task {
            let result = await finderController.openFoldersAsTabs(
                group.paths, windowRect: group.windowRect,
                timeout: TimeInterval(configManager.config.settings.timeout)
            )
            handleTabResult(result, paths: group.paths)
        }
    }

    /// FinderTabResult を処理して適切な UI フィードバックを表示
    func handleTabResult(_ result: FinderTabResult, paths: [String]) {
        switch result {
        case .success(let count):
            for path in paths {
                configManager.addHistory(path: path)
            }
            _ = count
        case .partialSuccess(let opened, let failed, _):
            for path in paths {
                configManager.addHistory(path: path)
            }
            showAlert(
                title: L("error.warning"),
                message: L("error.success_count").localized(opened, failed)
            )
        case .noFinderWindow:
            showAlert(title: L("error.title"), message: L("error.no_finder_window"))
        case .noTabBar:
            showAlert(title: L("error.title"), message: L("error.tab_bar_hidden"))
        case .accessibilityDenied:
            showAccessibilityDialog()
        case .invalidPaths(let invalid, let validResult):
            // 無効パスを警告表示
            let invalidList = invalid.joined(separator: "\n")
            showAlert(
                title: L("error.warning"),
                message: L("error.invalid_paths").localized(String(invalid.count)) + "\n\n" + invalidList
            )
            // 有効パス分の結果も処理
            handleTabResult(validResult, paths: paths)
        }
    }

    // MARK: - ダイアログ

    func showInputDialog(title: String, message: String, defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("dialog.ok"))
        alert.addButton(withTitle: L("dialog.cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    func showConfirmDialog(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("dialog.yes"))
        alert.addButton(withTitle: L("dialog.no"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("dialog.ok"))
        alert.runModal()
    }

    /// アクセシビリティ権限の説明ダイアログ
    /// 「システム設定を開く」ボタンでプライバシー設定を直接開く
    func showAccessibilityDialog() {
        logInfo("Showing accessibility permission dialog")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("accessibility.title")
        alert.informativeText = L("accessibility.message")
        alert.addButton(withTitle: L("accessibility.open_settings"))
        alert.addButton(withTitle: L("dialog.cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            logInfo("User chose to open System Settings")
            // AXIsProcessTrustedWithOptions で OS のプロンプトを表示
            // → システム設定 > プライバシーとセキュリティ > アクセシビリティ が開く
            FinderTabController.requestAccessibility()
        }
    }
}
