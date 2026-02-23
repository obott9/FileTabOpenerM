//
//  ContentView.swift
//  FileTabOpenerM
//
//  Created by 尾保手　秀樹 on 2026/02/24.
//

import SwiftUI

// MARK: - FlowLayout (タブボタンの折り返しレイアウト)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            height += row.height
            if i > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: max(height, 28))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            if i > 0 { y += spacing }
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height
        }
    }

    private struct Row {
        var subviews: [LayoutSubviews.Element]
        var height: CGFloat
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow: [LayoutSubviews.Element] = []
        var usedWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = currentRow.isEmpty ? size.width : size.width + spacing
            if !currentRow.isEmpty && usedWidth + needed > maxWidth {
                rows.append(Row(subviews: currentRow, height: rowHeight))
                currentRow = []
                usedWidth = 0
                rowHeight = 0
            }
            currentRow.append(subview)
            usedWidth += needed
            rowHeight = max(rowHeight, size.height)
        }
        if !currentRow.isEmpty {
            rows.append(Row(subviews: currentRow, height: rowHeight))
        }
        return rows
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var configManager = ConfigManager.shared
    @StateObject private var finderController = FinderTabController()

    @State private var selectedGroupID: UUID?
    @State private var historyText = ""
    @State private var showHistoryDropdown = false
    @State private var newPath = ""
    @State private var selectedPathIndex: Int?

    // ジオメトリ編集用
    @State private var geomX = ""
    @State private var geomY = ""
    @State private var geomW = ""
    @State private var geomH = ""

    var body: some View {
        VStack(spacing: 0) {
            // --- Settings bar (右寄せ) ---
            settingsBar
                .padding(.horizontal, 10)
                .padding(.top, 5)

            Divider().padding(.horizontal, 10).padding(.vertical, 5)

            // --- History section ---
            historySection
                .padding(.horizontal, 10)

            Divider().padding(.horizontal, 10).padding(.vertical, 5)

            // --- Tab group section (残りを埋める) ---
            tabGroupSection
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(minWidth: 600, minHeight: 400)
        .overlay {
            if finderController.isOpening {
                VStack {
                    Text("タブを開いています...")
                        .font(.title3)
                        .padding(20)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
            }
        }
        .onAppear { loadInitialState() }
    }

    // MARK: - Settings Bar

    private var settingsBar: some View {
        HStack {
            Spacer()
            Text("タイムアウト").font(.caption)
            Picker("", selection: $configManager.config.settings.timeout) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { val in
                    Text("\(val)").tag(val)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)
            .onChange(of: configManager.config.settings.timeout) { _, _ in
                configManager.save()
            }
            Text("秒").font(.caption)

            Text("🌐")
            Picker("", selection: $configManager.config.settings.language) {
                Text("Auto").tag("auto")
                Text("English").tag("en")
                Text("日本語").tag("ja")
                Text("한국어").tag("ko")
                Text("简体中文").tag("zh_CN")
                Text("繁體中文").tag("zh_TW")
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: configManager.config.settings.language) { _, _ in
                configManager.save()
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        HStack {
            Text("履歴:").font(.callout)

            TextField("パスを入力またはドロップ", text: $historyText)
                .textFieldStyle(.roundedBorder)

            Button("▼") { showHistoryDropdown.toggle() }
                .popover(isPresented: $showHistoryDropdown) {
                    historyDropdownContent
                }

            Button("Finderで開く") { openSingleFolder() }
            Button("📌") { toggleHistoryPin() }.frame(width: 36)
            Button("クリア") { clearHistory() }
        }
    }

    private var historyDropdownContent: some View {
        let sorted = configManager.sortedHistory()
        return VStack(spacing: 0) {
            if sorted.isEmpty {
                Text("履歴がありません")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sorted) { entry in
                            Button(action: {
                                historyText = entry.path
                                showHistoryDropdown = false
                            }) {
                                HStack {
                                    Text(entry.pinned ? "📌" : "   ")
                                        .frame(width: 24)
                                    Text(entry.path)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: min(CGFloat(max(sorted.count, 1)) * 28, 280))
    }

    // MARK: - Tab Group Section

    private var tabGroupSection: some View {
        VStack(spacing: 5) {
            // タブ管理バー
            tabManagementBar

            // タブボタン (折り返し、最大3行、スクロール)
            tabButtonsView

            // ウィンドウジオメトリ設定
            geometrySection

            // コンテンツ (パスリスト + アクションボタン)
            contentArea

            // パス入力
            pathEntrySection

            // タブで開くボタン
            openButton
        }
    }

    // MARK: - Tab Management Bar

    private var tabManagementBar: some View {
        HStack(spacing: 4) {
            Button("追加") { addTabGroup() }
            Button("削除") { deleteSelectedGroup() }
            Button("名前変更") { renameSelectedGroup() }
            Button("コピー") { copySelectedGroup() }

            Spacer().frame(width: 10)

            Button("◀") { moveSelectedGroupLeft() }.frame(width: 30)
            Button("▶") { moveSelectedGroupRight() }.frame(width: 30)

            Spacer()
        }
    }

    // MARK: - Tab Buttons View (折り返し)

    private var tabButtonsView: some View {
        ScrollView(.vertical) {
            FlowLayout(spacing: 4) {
                ForEach(configManager.config.tabGroups) { group in
                    Button(action: { selectGroup(group.id) }) {
                        Text(group.name)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                selectedGroupID == group.id
                                    ? Color.accentColor
                                    : Color.gray.opacity(0.3)
                            )
                            .foregroundColor(
                                selectedGroupID == group.id ? .white : .primary
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .frame(height: 96) // 3行 × 32px
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Geometry Section

    private var geometrySection: some View {
        HStack {
            Text("X:").font(.caption)
            TextField("", text: $geomX)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onSubmit { saveGeometry() }

            Text("Y:").font(.caption)
            TextField("", text: $geomY)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onSubmit { saveGeometry() }

            Text("W:").font(.caption)
            TextField("", text: $geomW)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onSubmit { saveGeometry() }

            Text("H:").font(.caption)
            TextField("", text: $geomH)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onSubmit { saveGeometry() }

            Button("Finderから取得") { getFinderBounds() }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Content Area (パスリスト + ボタン)

    private var contentArea: some View {
        HStack(alignment: .top, spacing: 5) {
            // パスリスト (左)
            pathListView

            // アクションボタン (右)
            VStack(spacing: 4) {
                Button("▲ 上へ") { movePathUp() }.frame(width: 80)
                Button("▼ 下へ") { movePathDown() }.frame(width: 80)
                Button("+ 追加") { addPathFromEntry() }.frame(width: 80)
                Button("- 削除") { removeSelectedPath() }.frame(width: 80)
                Button("参照...") { browseFolder() }.frame(width: 80)
            }
        }
    }

    private var pathListView: some View {
        Group {
            if let gi = selectedGroupIndex {
                List(selection: $selectedPathIndex) {
                    ForEach(Array(configManager.config.tabGroups[gi].paths.enumerated()),
                            id: \.offset) { offset, path in
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .tag(offset)
                    }
                }
                .listStyle(.bordered)
                .onChange(of: selectedPathIndex) { _, newIndex in
                    if let pi = newIndex,
                       configManager.config.tabGroups[gi].paths.indices.contains(pi) {
                        newPath = configManager.config.tabGroups[gi].paths[pi]
                    }
                }
            } else {
                List { }
                    .listStyle(.bordered)
            }
        }
    }

    // MARK: - Path Entry

    private var pathEntrySection: some View {
        TextField("フォルダパスを入力", text: $newPath)
            .textFieldStyle(.roundedBorder)
            .onSubmit { addPathFromEntry() }
            .padding(.vertical, 2)
    }

    // MARK: - Open Button

    private var openButton: some View {
        Button(action: { openTabs() }) {
            HStack {
                Image(systemName: "macwindow.badge.plus")
                Text("タブで開く")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .controlSize(.large)
        .disabled(
            selectedGroupIndex == nil
            || configManager.config.tabGroups[selectedGroupIndex!].paths.isEmpty
            || finderController.isOpening
        )
    }

    // MARK: - Computed

    private var selectedGroupIndex: Int? {
        guard let id = selectedGroupID else { return nil }
        return configManager.config.tabGroups.firstIndex(where: { $0.id == id })
    }

    // MARK: - 初期化

    private func loadInitialState() {
        if configManager.config.tabGroups.isEmpty {
            configManager.addTabGroup(name: "Tab 1")
        }
        selectedGroupID = configManager.config.tabGroups.first?.id
        loadGeometry()
    }

    private func selectGroup(_ id: UUID) {
        saveGeometry()
        selectedGroupID = id
        selectedPathIndex = nil
        loadGeometry()
    }

    // MARK: - タブグループ管理

    private func addTabGroup() {
        guard let name = showInputDialog(
            title: "タブ追加",
            message: "新しいタブの名前を入力:",
            defaultValue: "Tab \(configManager.config.tabGroups.count + 1)"
        ) else { return }
        if configManager.config.tabGroups.contains(where: { $0.name == name }) {
            showAlert(title: "重複", message: "「\(name)」は既に存在します。")
            return
        }
        configManager.addTabGroup(name: name)
        selectedGroupID = configManager.config.tabGroups.last?.id
        loadGeometry()
    }

    private func deleteSelectedGroup() {
        guard let id = selectedGroupID,
              let index = selectedGroupIndex else { return }
        let name = configManager.config.tabGroups[index].name
        guard showConfirmDialog(
            title: "削除確認",
            message: "「\(name)」を削除しますか？"
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

    private func renameSelectedGroup() {
        guard let index = selectedGroupIndex else { return }
        let oldName = configManager.config.tabGroups[index].name
        guard let newName = showInputDialog(
            title: "名前変更",
            message: "新しい名前を入力:",
            defaultValue: oldName
        ) else { return }
        if newName == oldName { return }
        if configManager.config.tabGroups.contains(where: { $0.name == newName }) {
            showAlert(title: "重複", message: "「\(newName)」は既に存在します。")
            return
        }
        configManager.config.tabGroups[index].name = newName
        configManager.save()
    }

    private func copySelectedGroup() {
        guard let id = selectedGroupID else { return }
        configManager.duplicateTabGroup(id: id)
        if let origIndex = configManager.config.tabGroups.firstIndex(where: { $0.id == id }),
           origIndex + 1 < configManager.config.tabGroups.count {
            selectedGroupID = configManager.config.tabGroups[origIndex + 1].id
        }
        loadGeometry()
    }

    private func moveSelectedGroupLeft() {
        guard let index = selectedGroupIndex, index > 0 else { return }
        configManager.config.tabGroups.swapAt(index, index - 1)
        configManager.save()
    }

    private func moveSelectedGroupRight() {
        guard let index = selectedGroupIndex,
              index < configManager.config.tabGroups.count - 1 else { return }
        configManager.config.tabGroups.swapAt(index, index + 1)
        configManager.save()
    }

    // MARK: - パス管理

    private func addPathFromEntry() {
        let path = newPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty, let gi = selectedGroupIndex else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        configManager.config.tabGroups[gi].paths.append(expanded)
        configManager.save()
        newPath = ""
    }

    private func removeSelectedPath() {
        guard let gi = selectedGroupIndex,
              let pi = selectedPathIndex,
              configManager.config.tabGroups[gi].paths.indices.contains(pi) else { return }
        configManager.config.tabGroups[gi].paths.remove(at: pi)
        configManager.save()
        selectedPathIndex = nil
    }

    private func movePathUp() {
        guard let gi = selectedGroupIndex,
              let pi = selectedPathIndex, pi > 0 else { return }
        configManager.config.tabGroups[gi].paths.swapAt(pi, pi - 1)
        configManager.save()
        selectedPathIndex = pi - 1
    }

    private func movePathDown() {
        guard let gi = selectedGroupIndex,
              let pi = selectedPathIndex,
              pi < configManager.config.tabGroups[gi].paths.count - 1 else { return }
        configManager.config.tabGroups[gi].paths.swapAt(pi, pi + 1)
        configManager.save()
        selectedPathIndex = pi + 1
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "フォルダを選択してください"
        if panel.runModal() == .OK, let url = panel.urls.first {
            newPath = url.path
        }
    }

    // MARK: - ジオメトリ

    private func loadGeometry() {
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

    private func saveGeometry() {
        guard let gi = selectedGroupIndex else { return }
        configManager.config.tabGroups[gi].windowX = Int(geomX)
        configManager.config.tabGroups[gi].windowY = Int(geomY)
        configManager.config.tabGroups[gi].windowWidth = clampMin(Int(geomW), 528)
        configManager.config.tabGroups[gi].windowHeight = clampMin(Int(geomH), 308)
        if let w = configManager.config.tabGroups[gi].windowWidth { geomW = String(w) }
        if let h = configManager.config.tabGroups[gi].windowHeight { geomH = String(h) }
        configManager.save()
    }

    private func clampMin(_ value: Int?, _ minimum: Int) -> Int? {
        guard let v = value else { return nil }
        return max(v, minimum)
    }

    private func getFinderBounds() {
        let script = """
        tell application "Finder" to get bounds of front Finder window
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        guard let result = appleScript?.executeAndReturnError(&error),
              result.numberOfItems == 4 else {
            showAlert(title: "エラー", message: "Finderウィンドウが見つかりません")
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
        saveGeometry()
    }

    // MARK: - 履歴

    private func openSingleFolder() {
        let path = historyText.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            showAlert(title: "エラー", message: "パスが見つかりません: \(path)")
            return
        }
        configManager.addHistory(path: expanded)
        NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
    }

    private func toggleHistoryPin() {
        let path = historyText.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        if !configManager.config.history.contains(where: { $0.path == expanded }) {
            configManager.addHistory(path: expanded)
        }
        configManager.togglePin(path: expanded)
    }

    private func clearHistory() {
        guard showConfirmDialog(
            title: "履歴クリア",
            message: "履歴をクリアしますか？（ピン留めは保持）"
        ) else { return }
        configManager.clearHistory(keepPinned: true)
    }

    // MARK: - タブで開く

    private func openTabs() {
        guard let gi = selectedGroupIndex else { return }
        let group = configManager.config.tabGroups[gi]
        saveGeometry()

        Task {
            let result = await finderController.openFoldersAsTabs(
                group.paths, windowRect: group.windowRect
            )
            switch result {
            case .success(let count):
                for path in group.paths {
                    configManager.addHistory(path: path)
                }
                // 成功時は静かに完了
                _ = count
            case .partialSuccess(let opened, let failed, _):
                showAlert(title: "警告", message: "\(opened) 個成功, \(failed) 個失敗")
            case .noFinderWindow:
                showAlert(title: "エラー", message: "Finderウィンドウが見つかりません")
            case .noTabBar:
                showAlert(title: "エラー", message: "タブバーが非表示です（表示→タブバーを表示）")
            case .accessibilityDenied:
                showAlert(title: "エラー", message: "アクセシビリティ権限が必要です")
                FinderTabController.requestAccessibility()
            }
        }
    }

    // MARK: - ダイアログ

    private func showInputDialog(title: String, message: String, defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "キャンセル")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private func showConfirmDialog(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "はい")
        alert.addButton(withTitle: "いいえ")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

#Preview {
    ContentView()
}
