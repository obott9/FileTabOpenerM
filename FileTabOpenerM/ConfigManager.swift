// ConfigManager.swift
// FileTabOpenerM
//
// JSON 設定ファイルの読み書き
// 保存先: ~/Library/Application Support/FileTabOpener/config.json
// (Python 版と同じパス・フォーマットで互換性あり)

import Combine
import Foundation

final class ConfigManager: ObservableObject {

    @Published var config: AppConfig

    private let configURL: URL

    static let shared = ConfigManager()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("FileTabOpener")
        configURL = configDir.appendingPathComponent("config.json")

        // デフォルト値で初期化 → load で上書き
        config = AppConfig()
        load()
    }

    // MARK: - Load / Save

    func load() {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            config = try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("Config load error: \(error)")
        }
    }

    func save() {
        do {
            let dir = configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL)
        } catch {
            print("Config save error: \(error)")
        }
    }

    // MARK: - タブグループ操作

    func addTabGroup(name: String) {
        config.tabGroups.append(TabGroup(name: name))
        save()
    }

    func deleteTabGroup(at index: Int) {
        guard config.tabGroups.indices.contains(index) else { return }
        config.tabGroups.remove(at: index)
        save()
    }

    func deleteTabGroup(id: UUID) {
        config.tabGroups.removeAll { $0.id == id }
        save()
    }

    func duplicateTabGroup(id: UUID) {
        guard let original = config.tabGroups.first(where: { $0.id == id }),
              let index = config.tabGroups.firstIndex(where: { $0.id == id }) else { return }
        var copy = TabGroup(name: nextCopyName(original.name), paths: original.paths)
        copy.windowX = original.windowX
        copy.windowY = original.windowY
        copy.windowWidth = original.windowWidth
        copy.windowHeight = original.windowHeight
        config.tabGroups.insert(copy, at: index + 1)
        save()
    }

    /// コピー名を生成: "Work" → "Work 1" → "Work 2"
    private func nextCopyName(_ baseName: String) -> String {
        let existingNames = Set(config.tabGroups.map(\.name))
        // ベース名から既存の番号サフィックスを除去
        let stripped: String
        if let range = baseName.range(of: #" \d+$"#, options: .regularExpression) {
            stripped = String(baseName[..<range.lowerBound])
        } else {
            stripped = baseName
        }
        for i in 1... {
            let candidate = "\(stripped) \(i)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }
        return "\(stripped) copy" // fallback (到達しない)
    }

    // MARK: - 履歴操作

    private let maxHistory = 50

    func addHistory(path: String) {
        if let index = config.history.firstIndex(where: { $0.path == path }) {
            config.history[index].lastUsed = Date()
            config.history[index].useCount += 1
        } else {
            config.history.append(HistoryEntry(path: path))
        }
        trimHistory()
        save()
    }

    func togglePin(path: String) {
        if let index = config.history.firstIndex(where: { $0.path == path }) {
            config.history[index].pinned.toggle()
            save()
        }
    }

    func clearHistory(keepPinned: Bool = true) {
        if keepPinned {
            config.history.removeAll { !$0.pinned }
        } else {
            config.history.removeAll()
        }
        save()
    }

    /// 履歴をソート: ピン留め (新しい順) → 非ピン (新しい順)
    func sortedHistory() -> [HistoryEntry] {
        let pinned = config.history.filter(\.pinned).sorted { $0.lastUsed > $1.lastUsed }
        let unpinned = config.history.filter { !$0.pinned }.sorted { $0.lastUsed > $1.lastUsed }
        return pinned + unpinned
    }

    private func trimHistory() {
        guard config.history.count > maxHistory else { return }
        let pinned = config.history.filter(\.pinned)
        var unpinned = config.history.filter { !$0.pinned }
        unpinned.sort { $0.lastUsed > $1.lastUsed }
        let keep = maxHistory - pinned.count
        if keep > 0 {
            config.history = pinned + Array(unpinned.prefix(keep))
        } else {
            config.history = pinned
        }
    }
}
