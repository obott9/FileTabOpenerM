//
//  ContentView.swift
//  FileTabOpenerM
//
//  Created by 尾保手　秀樹 on 2026/02/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var configManager = ConfigManager.shared
    @StateObject private var finderController = FinderTabController()
    @State private var selectedGroupID: UUID?
    @State private var newGroupName = ""
    @State private var newPath = ""
    @State private var statusMessage = ""

    var body: some View {
        HSplitView {
            // 左: タブグループ一覧
            sidebarView
                .frame(minWidth: 180, maxWidth: 250)

            // 右: 選択中グループの詳細
            detailView
                .frame(minWidth: 350)
        }
        .frame(minWidth: 560, minHeight: 380)
        .onAppear {
            // 最初のグループを選択
            if selectedGroupID == nil {
                selectedGroupID = configManager.config.tabGroups.first?.id
            }
        }
    }

    // MARK: - サイドバー (タブグループ一覧)

    private var sidebarView: some View {
        VStack(spacing: 0) {
            List(selection: $selectedGroupID) {
                ForEach(configManager.config.tabGroups) { group in
                    Text(group.name)
                        .tag(group.id)
                        .contextMenu {
                            Button("複製") {
                                configManager.duplicateTabGroup(id: group.id)
                            }
                            Divider()
                            Button("削除", role: .destructive) {
                                if selectedGroupID == group.id {
                                    selectedGroupID = nil
                                }
                                configManager.deleteTabGroup(id: group.id)
                            }
                        }
                }
                .onMove { from, to in
                    configManager.config.tabGroups.move(fromOffsets: from, toOffset: to)
                    configManager.save()
                }
            }
            .listStyle(.sidebar)

            Divider()

            // グループ追加
            HStack {
                TextField("新規グループ名", text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addGroup() }

                Button(action: addGroup) {
                    Image(systemName: "plus")
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
    }

    // MARK: - 詳細ビュー (パス一覧 + 操作)

    private var detailView: some View {
        Group {
            if let groupID = selectedGroupID,
               let groupIndex = configManager.config.tabGroups.firstIndex(where: { $0.id == groupID }) {
                VStack(spacing: 0) {
                    // グループ名 (編集可能)
                    HStack {
                        TextField("グループ名", text: $configManager.config.tabGroups[groupIndex].name)
                            .textFieldStyle(.roundedBorder)
                            .font(.headline)
                            .onChange(of: configManager.config.tabGroups[groupIndex].name) { _, _ in
                                configManager.save()
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // パス一覧
                    List {
                        ForEach(Array(configManager.config.tabGroups[groupIndex].paths.enumerated()), id: \.offset) { offset, path in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(action: {
                                    configManager.config.tabGroups[groupIndex].paths.remove(at: offset)
                                    configManager.save()
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove { from, to in
                            configManager.config.tabGroups[groupIndex].paths.move(fromOffsets: from, toOffset: to)
                            configManager.save()
                        }
                    }

                    Divider()

                    // パス追加
                    HStack {
                        TextField("フォルダパスを入力", text: $newPath)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addPath(to: groupIndex) }

                        Button("追加") { addPath(to: groupIndex) }
                            .disabled(newPath.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(action: { browseFolder(for: groupIndex) }) {
                            Image(systemName: "folder.badge.plus")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    Divider()

                    // 開くボタン + ステータス
                    HStack {
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(statusMessage.contains("✅") ? .green : .secondary)
                        }
                        Spacer()
                        Button(action: { openTabs(groupIndex: groupIndex) }) {
                            HStack {
                                Image(systemName: "macwindow.badge.plus")
                                Text("タブで開く")
                            }
                        }
                        .controlSize(.large)
                        .disabled(configManager.config.tabGroups[groupIndex].paths.isEmpty || finderController.isOpening)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            } else {
                VStack {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("タブグループを選択してください")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - アクション

    private func addGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        configManager.addTabGroup(name: name)
        selectedGroupID = configManager.config.tabGroups.last?.id
        newGroupName = ""
    }

    private func addPath(to groupIndex: Int) {
        let path = newPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        configManager.config.tabGroups[groupIndex].paths.append(expanded)
        configManager.save()
        newPath = ""
    }

    private func browseFolder(for groupIndex: Int) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "フォルダを選択してください"

        if panel.runModal() == .OK {
            for url in panel.urls {
                configManager.config.tabGroups[groupIndex].paths.append(url.path)
            }
            configManager.save()
        }
    }

    private func openTabs(groupIndex: Int) {
        let group = configManager.config.tabGroups[groupIndex]
        statusMessage = "開いています..."

        Task {
            let result = await finderController.openFoldersAsTabs(
                group.paths,
                windowRect: group.windowRect
            )

            switch result {
            case .success(let count):
                statusMessage = "✅ \(count) 個のタブを開きました"
                // 履歴に追加
                for path in group.paths {
                    configManager.addHistory(path: path)
                }
            case .partialSuccess(let opened, let failed, _):
                statusMessage = "⚠️ \(opened) 個成功, \(failed) 個失敗"
            case .noFinderWindow:
                statusMessage = "❌ Finder ウィンドウが見つかりません"
            case .noTabBar:
                statusMessage = "❌ タブバーが非表示です (表示 → タブバーを表示)"
            case .accessibilityDenied:
                statusMessage = "❌ アクセシビリティ権限が必要です"
                FinderTabController.requestAccessibility()
            }

            // 3秒後にステータスをクリア
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            statusMessage = ""
        }
    }
}

#Preview {
    ContentView()
}
