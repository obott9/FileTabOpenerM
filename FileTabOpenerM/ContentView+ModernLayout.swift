// ContentView+ModernLayout.swift
// FileTabOpenerM
//
// Modern レイアウト (サイドバー方式) のビュー定義
// ContentView.swift から分離

import SwiftUI

extension ContentView {

    // MARK: - Modern Tab Group Section (サイドバー方式)

    var modernTabGroupSection: some View {
        HSplitView {
            // 左: タブグループ一覧
            modernSidebar
                .frame(minWidth: 160, maxWidth: 240)

            // 右: 選択中グループの詳細
            modernDetail
                .frame(minWidth: 350)
        }
    }

    var modernSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedGroupID) {
                ForEach(configManager.config.tabGroups) { group in
                    Text(group.name)
                        .tag(group.id)
                        .contextMenu {
                            Button(L("tab.rename")) { renameSelectedGroup() }
                            Button(L("tab.copy")) { copySelectedGroup() }
                            Divider()
                            Button(L("tab.delete"), role: .destructive) { deleteSelectedGroup() }
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
                TextField(L("modern.new_group"), text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addGroupFromTextField() }

                Button(action: addGroupFromTextField) {
                    Image(systemName: "plus")
                }
                .buttonStyle(CTkButtonStyle())
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
    }

    var modernDetail: some View {
        Group {
            if let gi = selectedGroupIndex {
                VStack(spacing: 0) {
                    // グループ名 (インライン編集)
                    TextField(L("modern.new_group"), text: $configManager.config.tabGroups[gi].name)
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

                    // パスリスト (ドラッグ並べ替え + 右クリック削除対応)
                    modernPathListView
                        .padding(.horizontal, 12)
                        .padding(.top, 4)

                    Divider()

                    // パス入力 + 参照
                    HStack {
                        TextField(L("path.placeholder"), text: $newPath)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addPathFromEntry() }
                            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                                handleFileDrop(providers)
                            }

                        Button(L("tab.add")) { addPathFromEntry() }
                            .buttonStyle(CTkButtonStyle())
                            .disabled(newPath.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(action: { browseFolder() }) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(CTkButtonStyle())
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
                    Text(L("modern.select_group"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Modern Path List View (ドラッグ並べ替え + 削除対応)

    var modernPathListView: some View {
        Group {
            if let gi = selectedGroupIndex {
                List(selection: $selectedPathIndex) {
                    ForEach(Array(configManager.config.tabGroups[gi].paths.enumerated()),
                            id: \.offset) { offset, path in
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .tag(offset)
                            .contextMenu {
                                Button(L("tab.delete"), role: .destructive) {
                                    deletePath(at: offset, in: gi)
                                }
                            }
                    }
                    .onDelete { offsets in
                        deletePathsAtOffsets(offsets)
                    }
                    .onMove { from, to in
                        movePathsFromOffsets(from, to: to)
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
}
