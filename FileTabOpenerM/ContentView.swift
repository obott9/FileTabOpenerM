//
//  ContentView.swift
//  FileTabOpenerM
//
//  Created by 尾保手　秀樹 on 2026/02/24.
//
//  分割構成:
//    Theme.swift                     — テーマ色定数, CTkButtonStyle, Color拡張
//    FlowLayout.swift                — タブボタン折り返しレイアウト
//    ContentView.swift               — body, 共有ビュー, State (本ファイル)
//    ContentView+ClassicLayout.swift — Classic レイアウト
//    ContentView+ModernLayout.swift  — Modern レイアウト
//    ContentView+Actions.swift       — アクションメソッド全般

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView

struct ContentView: View {
    @StateObject var configManager = ConfigManager.shared
    @StateObject var finderController = FinderTabController()

    @AppStorage("useModernLayout") var useModernLayout = false
    @State var selectedGroupID: UUID?
    @State var historyText = ""
    @State var showHistoryDropdown = false
    @State var newPath = ""
    @State var newGroupName = ""
    @State var selectedPathIndex: Int?

    // ジオメトリ編集用
    @State var geomX = ""
    @State var geomY = ""
    @State var geomW = ""
    @State var geomH = ""

    var body: some View {
        VStack(spacing: 0) {
            // --- Settings bar (右寄せ) ---
            settingsBar
                .padding(.horizontal, 10)
                .padding(.top, 5)

            // --- History section ---
            historySection
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(PythonTheme.frameBg)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)

            Divider().padding(.horizontal, 10).padding(.vertical, 5)

            // --- Tab group section ---
            if useModernLayout {
                modernTabGroupSection
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(PythonTheme.frameBg)
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                classicTabGroupSection
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(PythonTheme.frameBg)
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .frame(minWidth: 600, minHeight: 400)  // Python版と同じ最小サイズ
        .overlay {
            if finderController.isOpening {
                VStack(spacing: 8) {
                    if finderController.openingTotal > 0 {
                        Text(L("toast.progress")
                            .localized(finderController.openingCurrent)
                            .localized(finderController.openingTotal))
                            .font(.body.bold())
                    } else {
                        Text(L("toast.opening"))
                            .font(.body.bold())
                    }
                    if !finderController.openingPath.isEmpty {
                        Text(compactPath(finderController.openingPath))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(L("toast.wait"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
            }
        }
        .onAppear { loadInitialState() }
        // S6: Keyboard shortcut receivers
        .onReceive(NotificationCenter.default.publisher(for: .addTabGroup)) { _ in
            addTabGroup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteTabGroup)) { _ in
            deleteSelectedGroup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTabs)) { _ in
            openTabs()
        }
    }

    // MARK: - Settings Bar

    var settingsBar: some View {
        HStack {
            Picker("", selection: $useModernLayout) {
                Text("Classic").tag(false)
                Text("Modern").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()
            Text(L("settings.timeout")).font(.body)
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
            Text(L("settings.seconds")).font(.body)

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

    var historySection: some View {
        HStack {
            Text(L("history.label")).font(.body)

            TextField(L("history.placeholder"), text: $historyText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("History path input")
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleFileDropToHistory(providers)
                }

            Button("\u{25BC}") { showHistoryDropdown.toggle() }
                .accessibilityLabel("Show history dropdown")
                .popover(isPresented: $showHistoryDropdown) {
                    historyDropdownContent
                }

            Button(L("history.open")) { openSingleFolder() }
                .buttonStyle(CTkButtonStyle())
                .accessibilityLabel("Open folder in Finder")
            Button("\u{1F4CC}") { toggleHistoryPin() }
                .buttonStyle(CTkButtonStyle())
                .accessibilityLabel("Toggle pin")
            Button(L("history.clear")) { clearHistory() }
                .buttonStyle(CTkButtonStyle())
                .accessibilityLabel("Clear history")
        }
    }

    var historyDropdownContent: some View {
        let sorted = configManager.sortedHistory()
        return VStack(spacing: 0) {
            if sorted.isEmpty {
                Text(L("history.empty"))
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

    // MARK: - Geometry Section (Classic / Modern 共有)

    var geometrySection: some View {
        HStack {
            Text("X:").font(.body)
            TextField("", text: $geomX)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .accessibilityLabel("Window X position")
                .onSubmit { saveGeometry() }

            Text("Y:").font(.body)
            TextField("", text: $geomY)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .accessibilityLabel("Window Y position")
                .onSubmit { saveGeometry() }

            Text("W:").font(.body)
            TextField("", text: $geomW)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .accessibilityLabel("Window width")
                .onSubmit { saveGeometry() }

            Text("H:").font(.body)
            TextField("", text: $geomH)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .accessibilityLabel("Window height")
                .onSubmit { saveGeometry() }

            Button(L("geometry.get")) { getFinderBounds() }
                .buttonStyle(CTkButtonStyle())

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Open Button (Classic / Modern 共有)

    var openButton: some View {
        let isDisabled = selectedGroupIndex == nil
            || configManager.config.tabGroups[selectedGroupIndex!].paths.isEmpty
            || finderController.isOpening

        return Button(action: { openTabs() }) {
            HStack {
                Image(systemName: "macwindow.badge.plus")
                Text(L("action.open_tabs"))
            }
            .font(.body)
            .foregroundColor(isDisabled ? PythonTheme.buttonText.opacity(0.5) : PythonTheme.buttonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDisabled ? PythonTheme.buttonBg.opacity(0.4) : PythonTheme.buttonBg)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("Open all paths as Finder tabs")
    }

    // MARK: - Computed

    var selectedGroupIndex: Int? {
        guard let id = selectedGroupID else { return nil }
        return configManager.config.tabGroups.firstIndex(where: { $0.id == id })
    }

    /// トースト用パス短縮 (最大45文字、先頭 + ... + 末尾)
    func compactPath(_ path: String) -> String {
        let maxLen = 45
        guard path.count > maxLen else { return path }
        let last = (path as NSString).lastPathComponent
        let prefix = String(path.prefix(maxLen - last.count - 4))
        return prefix + "/.../" + last
    }

    /// パス文字列のサニタイズ: 空白トリム + 前後のクォート除去
    func sanitizePath(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if (s.hasPrefix("'") && s.hasSuffix("'"))
            || (s.hasPrefix("\"") && s.hasSuffix("\"")) {
            s = String(s.dropFirst().dropLast())
        }
        return s
    }
}

#Preview {
    ContentView()
}
