// TabGroup.swift
// FileTabOpenerM
//
// タブグループのデータモデル
// Python版 (FileTabOpener) と設定ファイル互換

import AppKit

/// タブグループ: 名前 + パスリスト + ウィンドウジオメトリ
struct TabGroup: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var paths: [String]
    var windowX: Int?
    var windowY: Int?
    var windowWidth: Int?
    var windowHeight: Int?

    // id は JSON に含めない (Python版と互換)
    private enum CodingKeys: String, CodingKey {
        case name, paths, windowX, windowY, windowWidth, windowHeight
    }

    init(name: String, paths: [String] = []) {
        self.id = UUID()
        self.name = name
        self.paths = paths
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try c.decode(String.self, forKey: .name)
        paths = try c.decodeIfPresent([String].self, forKey: .paths) ?? []
        windowX = try c.decodeIfPresent(Int.self, forKey: .windowX)
        windowY = try c.decodeIfPresent(Int.self, forKey: .windowY)
        windowWidth = try c.decodeIfPresent(Int.self, forKey: .windowWidth)
        windowHeight = try c.decodeIfPresent(Int.self, forKey: .windowHeight)
    }

    /// ウィンドウジオメトリが設定されているか
    var hasWindowGeometry: Bool {
        windowX != nil && windowY != nil && windowWidth != nil && windowHeight != nil
    }

    /// NSRect に変換 (ジオメトリ未設定なら nil)
    var windowRect: NSRect? {
        guard let x = windowX, let y = windowY,
              let w = windowWidth, let h = windowHeight else { return nil }
        return NSRect(x: x, y: y, width: w, height: h)
    }
}

/// 履歴エントリ
struct HistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var pinned: Bool
    var lastUsed: Date
    var useCount: Int

    // id は JSON に含めない (Python版と互換)
    private enum CodingKeys: String, CodingKey {
        case path, pinned, lastUsed, useCount
    }

    init(path: String, pinned: Bool = false) {
        self.id = UUID()
        self.path = path
        self.pinned = pinned
        self.lastUsed = Date()
        self.useCount = 1
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        path = try c.decode(String.self, forKey: .path)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        lastUsed = try c.decode(Date.self, forKey: .lastUsed)
        useCount = try c.decodeIfPresent(Int.self, forKey: .useCount) ?? 1
    }
}

/// アプリ設定
struct AppSettings: Codable, Equatable {
    var timeout: Int = 30
    var language: String = "auto"

    // Python版の use_custom_tk 等は無視される
    private enum CodingKeys: String, CodingKey {
        case timeout, language
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timeout = try c.decodeIfPresent(Int.self, forKey: .timeout) ?? 30
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "auto"
    }
}

/// アプリ全体の設定データ
struct AppConfig: Codable {
    var tabGroups: [TabGroup] = []
    var history: [HistoryEntry] = []
    var settings: AppSettings = AppSettings()
    var windowGeometry: String = "600x400"
}
