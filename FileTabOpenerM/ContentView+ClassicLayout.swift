// ContentView+ClassicLayout.swift
// FileTabOpenerM
//
// Classic レイアウト (Python版準拠) のビュー定義
// ContentView.swift から分離

import SwiftUI

extension ContentView {

    // MARK: - Classic Tab Group Section (Python版準拠)

    var classicTabGroupSection: some View {
        VStack(spacing: 5) {
            // タブ管理バー
            tabManagementBar

            // タブボタン (折り返し、最大3行、スクロール)
            tabButtonsView

            // ウィンドウジオメトリ設定
            geometrySection

            // コンテンツ (パスリスト + ボタン)
            contentArea

            // パス入力
            pathEntrySection

            // タブで開くボタン
            openButton
        }
    }

    // MARK: - Tab Management Bar

    var tabManagementBar: some View {
        HStack(spacing: 4) {
            Button(L("tab.add_btn")) { addTabGroup() }
                .buttonStyle(CTkButtonStyle())
            Button(L("tab.delete_btn")) { deleteSelectedGroup() }
                .buttonStyle(CTkButtonStyle())
            Button(L("tab.rename")) { renameSelectedGroup() }
                .buttonStyle(CTkButtonStyle())
            Button(L("tab.copy_btn")) { copySelectedGroup() }
                .buttonStyle(CTkButtonStyle())

            Spacer().frame(width: 10)

            Button("\u{25C0}") { moveSelectedGroupLeft() }
                .buttonStyle(CTkButtonStyle())
            Button("\u{25B6}") { moveSelectedGroupRight() }
                .buttonStyle(CTkButtonStyle())

            Spacer()
        }
    }

    // MARK: - Tab Buttons View (折り返し)

    var tabButtonsView: some View {
        ScrollView(.vertical) {
            FlowLayout(spacing: 2) {
                ForEach(configManager.config.tabGroups) { group in
                    Button(action: { selectGroup(group.id) }) {
                        Text(group.name)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                selectedGroupID == group.id
                                    ? PythonTheme.tabSelectedBg
                                    : PythonTheme.tabUnselectedBg
                            )
                            .foregroundColor(
                                selectedGroupID == group.id
                                    ? PythonTheme.tabSelectedText
                                    : PythonTheme.tabUnselectedText
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
        }
        .frame(height: 102) // 3行 × 34px (Python: VISIBLE_ROWS=3, ROW_HEIGHT=32 + PAD_Y*2=2)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Content Area (パスリスト + ボタン)

    var contentArea: some View {
        HStack(alignment: .top, spacing: 5) {
            // パスリスト (左)
            classicPathListView

            // アクションボタン (右)
            VStack(spacing: 4) {
                Button(L("path.move_up")) { movePathUp() }
                    .buttonStyle(CTkButtonStyle())
                    .frame(width: 90)
                Button(L("path.move_down")) { movePathDown() }
                    .buttonStyle(CTkButtonStyle())
                    .frame(width: 90)
                Button(L("path.add")) { addPathFromEntry() }
                    .buttonStyle(CTkButtonStyle())
                    .frame(width: 90)
                Button(L("path.remove")) { removeSelectedPath() }
                    .buttonStyle(CTkButtonStyle())
                    .frame(width: 90)
                Button(L("path.browse")) { browseFolder() }
                    .buttonStyle(CTkButtonStyle())
                    .frame(width: 90)
            }
        }
    }

    var classicPathListView: some View {
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

    var pathEntrySection: some View {
        TextField(L("path.placeholder"), text: $newPath)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Folder path input")
            .onSubmit { addPathFromEntry() }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleFileDrop(providers)
            }
            .padding(.vertical, 2)
    }
}
