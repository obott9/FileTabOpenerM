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

    @AppStorage("useModernLayout") private var useModernLayout = false
    @State private var selectedGroupID: UUID?
    @State private var historyText = ""
    @State private var showHistoryDropdown = false
    @State private var newPath = ""
    @State private var newGroupName = ""
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

            // --- Tab group section ---
            if useModernLayout {
                modernTabGroupSection
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                classicTabGroupSection
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .overlay {
            if finderController.isOpening {
                VStack {
                    Text(L("opening_tabs"))
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
            Picker("", selection: $useModernLayout) {
                Text("Classic").tag(false)
                Text("Modern").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()
            Text(L("timeout")).font(.caption)
            Picker("", selection: $configManager.config.settings.timeout) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { val in
                    Text("\(val)").tag(val)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)
            .onChange(of: configManager.config.settings.timeout) { _, newVal in
                logInfo("Timeout changed to \(newVal)s")
                configManager.save()
            }
            Text(L("seconds")).font(.caption)

            Text("\u{1F310}")
            Picker("", selection: $configManager.config.settings.language) {
                Text("Auto").tag("auto")
                Text("English").tag("en")
                Text("\u{65E5}\u{672C}\u{8A9E}").tag("ja")
                Text("\u{D55C}\u{AD6D}\u{C5B4}").tag("ko")
                Text("\u{7C21}\u{4F53}\u{4E2D}\u{6587}").tag("zh_CN")
                Text("\u{7E41}\u{9AD4}\u{4E2D}\u{6587}").tag("zh_TW")
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: configManager.config.settings.language) { _, newVal in
                logInfo("Language changed to \(newVal)")
                configManager.save()
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        HStack {
            Text(L("history")).font(.callout)

            TextField(L("enter_path_or_drop"), text: $historyText)
                .textFieldStyle(.roundedBorder)

            Button("\u{25BC}") { showHistoryDropdown.toggle() }
                .popover(isPresented: $showHistoryDropdown) {
                    historyDropdownContent
                }

            Button(L("open_in_finder")) { openSingleFolder() }
            Button("\u{1F4CC}") { toggleHistoryPin() }.frame(width: 36)
            Button(L("clear")) { clearHistory() }
        }
    }

    private var historyDropdownContent: some View {
        let sorted = configManager.sortedHistory()
        return VStack(spacing: 0) {
            if sorted.isEmpty {
                Text(L("no_history"))
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
                                    Text(entry.pinned ? "\u{1F4CC}" : "   ")
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

    // MARK: - Classic Tab Group Section (Python版準拠)

    private var classicTabGroupSection: some View {
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
            Button(L("add")) { addTabGroup() }
            Button(L("delete")) { deleteSelectedGroup() }
            Button(L("rename")) { renameSelectedGroup() }
            Button(L("copy")) { copySelectedGroup() }

            Spacer().frame(width: 10)

            Button("\u{25C0}") { moveSelectedGroupLeft() }.frame(width: 30)
            Button("\u{25B6}") { moveSelectedGroupRight() }.frame(width: 30)

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

            Button(L("get_from_finder")) { getFinderBounds() }

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
                Button(L("move_up")) { movePathUp() }.frame(width: 80)
                Button(L("move_down")) { movePathDown() }.frame(width: 80)
                Button(L("add_path")) { addPathFromEntry() }.frame(width: 80)
                Button(L("remove_path")) { removeSelectedPath() }.frame(width: 80)
                Button(L("browse")) { browseFolder() }.frame(width: 80)
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
        TextField(L("enter_folder_path"), text: $newPath)
            .textFieldStyle(.roundedBorder)
            .onSubmit { addPathFromEntry() }
            .padding(.vertical, 2)
    }

    // MARK: - Open Button

    private var openButton: some View {
        Button(action: { openTabs() }) {
            HStack {
                Image(systemName: "macwindow.badge.plus")
                Text(L("open_as_tabs"))
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

    // MARK: - Modern Tab Group Section (サイドバー方式)

    private var modernTabGroupSection: some View {
        HSplitView {
            // 左: タブグループ一覧
            modernSidebar
                .frame(minWidth: 160, maxWidth: 240)

            // 右: 選択中グループの詳細
            modernDetail
                .frame(minWidth: 350)
        }
    }

    private var modernSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedGroupID) {
                ForEach(configManager.config.tabGroups) { group in
                    Text(group.name)
                        .tag(group.id)
                        .contextMenu {
                            Button(L("rename")) { renameSelectedGroup() }
                            Button(L("copy")) { copySelectedGroup() }
                            Divider()
                            Button(L("delete"), role: .destructive) { deleteSelectedGroup() }
                        }
                }
                .onMove { from, to in
                    configManager.config.tabGroups.move(fromOffsets: from, toOffset: to)
                    configManager.save()
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedGroupID) { _, newID in
                if newID != nil {
                    selectedPathIndex = nil
                    loadGeometry()
                }
            }

            Divider()

            HStack {
                TextField(L("new_group_name"), text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addGroupFromTextField() }

                Button(action: addGroupFromTextField) {
                    Image(systemName: "plus")
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
    }

    private var modernDetail: some View {
        Group {
            if let gi = selectedGroupIndex {
                VStack(spacing: 0) {
                    // グループ名 (インライン編集)
                    TextField(L("new_group_name"), text: $configManager.config.tabGroups[gi].name)
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)
                        .onChange(of: configManager.config.tabGroups[gi].name) { _, _ in
                            configManager.save()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    // ジオメトリ
                    geometrySection
                        .padding(.horizontal, 12)
                        .padding(.top, 4)

                    // パスリスト
                    pathListView
                        .padding(.horizontal, 12)
                        .padding(.top, 4)

                    Divider()

                    // パス入力 + 参照
                    HStack {
                        TextField(L("enter_folder_path"), text: $newPath)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addPathFromEntry() }

                        Button(L("add")) { addPathFromEntry() }
                            .disabled(newPath.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(action: { browseFolder() }) {
                            Image(systemName: "folder.badge.plus")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    Divider()

                    // 開くボタン
                    openButton
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            } else {
                VStack {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text(L("select_tab_group"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Computed

    private var selectedGroupIndex: Int? {
        guard let id = selectedGroupID else { return nil }
        return configManager.config.tabGroups.firstIndex(where: { $0.id == id })
    }

    /// パス文字列のサニタイズ: 空白トリム + 前後のクォート除去
    private func sanitizePath(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if (s.hasPrefix("'") && s.hasSuffix("'"))
            || (s.hasPrefix("\"") && s.hasSuffix("\"")) {
            s = String(s.dropFirst().dropLast())
        }
        return s
    }

    // MARK: - 初期化

    private func loadInitialState() {
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

    private func addGroupFromTextField() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if configManager.config.tabGroups.contains(where: { $0.name == name }) {
            showAlert(title: L("duplicate"), message: L("duplicate_msg").localized(name))
            return
        }
        configManager.addTabGroup(name: name)
        selectedGroupID = configManager.config.tabGroups.last?.id
        newGroupName = ""
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
            title: L("add_tab"),
            message: L("enter_new_tab_name"),
            defaultValue: "Tab \(configManager.config.tabGroups.count + 1)"
        ) else { return }
        if configManager.config.tabGroups.contains(where: { $0.name == name }) {
            showAlert(title: L("duplicate"), message: L("duplicate_msg").localized(name))
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
            title: L("delete_confirm"),
            message: L("delete_confirm_msg").localized(name)
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
            title: L("rename_tab"),
            message: L("enter_new_name"),
            defaultValue: oldName
        ) else { return }
        if newName == oldName { return }
        if configManager.config.tabGroups.contains(where: { $0.name == newName }) {
            showAlert(title: L("duplicate"), message: L("duplicate_msg").localized(newName))
            return
        }
        logInfo("Tab group renamed: \(oldName) -> \(newName)")
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
        let path = sanitizePath(newPath)
        guard !path.isEmpty, let gi = selectedGroupIndex else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        logInfo("Path added: \(expanded)")
        configManager.config.tabGroups[gi].paths.append(expanded)
        configManager.save()
        newPath = ""
    }

    private func removeSelectedPath() {
        guard let gi = selectedGroupIndex,
              let pi = selectedPathIndex,
              configManager.config.tabGroups[gi].paths.indices.contains(pi) else { return }
        let removed = configManager.config.tabGroups[gi].paths[pi]
        logInfo("Path removed: \(removed)")
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
        panel.message = L("enter_folder_path")
        if panel.runModal() == .OK, let url = panel.urls.first {
            newPath = url.path
            logInfo("Folder selected via browse: \(url.path)")
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
        logInfo("Getting Finder window bounds")
        let script = """
        tell application "Finder" to get bounds of front Finder window
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        guard let result = appleScript?.executeAndReturnError(&error),
              result.numberOfItems == 4 else {
            logError("Failed to get Finder bounds: \(error ?? [:])")
            showAlert(title: L("error"), message: L("no_finder_window"))
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

    private func openSingleFolder() {
        let path = sanitizePath(historyText)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            logWarning("Path not found: \(expanded)")
            showAlert(title: L("error"), message: L("path_not_found").localized(path))
            return
        }
        logInfo("Opening single folder: \(expanded)")
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
        logInfo("History pin toggled: \(expanded)")
    }

    private func clearHistory() {
        guard showConfirmDialog(
            title: L("clear_history"),
            message: L("clear_history_msg")
        ) else { return }
        configManager.clearHistory(keepPinned: true)
    }

    // MARK: - タブで開く

    private func openTabs() {
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
    private func handleTabResult(_ result: FinderTabResult, paths: [String]) {
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
                title: L("warning"),
                message: L("success_count").localized(opened, failed)
            )
        case .noFinderWindow:
            showAlert(title: L("error"), message: L("no_finder_window"))
        case .noTabBar:
            showAlert(title: L("error"), message: L("tab_bar_hidden"))
        case .accessibilityDenied:
            showAccessibilityDialog()
        case .invalidPaths(let invalid, let validResult):
            // 無効パスを警告表示
            let invalidList = invalid.joined(separator: "\n")
            showAlert(
                title: L("warning"),
                message: L("invalid_paths_msg").localized(String(invalid.count)) + "\n\n" + invalidList
            )
            // 有効パス分の結果も処理
            handleTabResult(validResult, paths: paths)
        }
    }

    // MARK: - ダイアログ

    private func showInputDialog(title: String, message: String, defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("ok"))
        alert.addButton(withTitle: L("cancel"))
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
        alert.addButton(withTitle: L("yes"))
        alert.addButton(withTitle: L("no"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("ok"))
        alert.runModal()
    }

    /// アクセシビリティ権限の説明ダイアログ
    /// 「システム設定を開く」ボタンでプライバシー設定を直接開く
    private func showAccessibilityDialog() {
        logInfo("Showing accessibility permission dialog")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("accessibility_dialog_title")
        alert.informativeText = L("accessibility_dialog_message")
        alert.addButton(withTitle: L("open_system_settings"))
        alert.addButton(withTitle: L("cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            logInfo("User chose to open System Settings")
            // AXIsProcessTrustedWithOptions で OS のプロンプトを表示
            // → システム設定 > プライバシーとセキュリティ > アクセシビリティ が開く
            FinderTabController.requestAccessibility()
        }
    }
}

#Preview {
    ContentView()
}
